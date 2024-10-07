use std::collections::HashMap;
use std::fs;
use std::rc::Rc;

use anyhow::{anyhow, Context, Result};
use cairo_lang_compiler::db::RootDatabase;
use cairo_lang_compiler::CompilerConfig;
use cairo_lang_defs::ids::NamedLanguageElementId;
use cairo_lang_filesystem::db::FilesGroup;
use cairo_lang_filesystem::ids::{CrateId, CrateLongId};
use cairo_lang_starknet::compile::compile_prepared_db;
use cairo_lang_starknet::contract::{find_contracts, ContractDeclaration};
use cairo_lang_starknet_classes::allowed_libfuncs::{AllowedLibfuncsError, ListSelector};
use cairo_lang_starknet_classes::contract_class::ContractClass;
use cairo_lang_utils::UpcastMut;
use dojo_types::naming;
use itertools::{izip, Itertools};
use scarb::compiler::helpers::build_compiler_config;
use scarb::compiler::{CairoCompilationUnit, CompilationUnitAttributes, Compiler};
use scarb::core::{Config, Package, TargetKind, Workspace};
use scarb::ops::CompileOpts;
use scarb_ui::args::{FeaturesSpec, PackagesFilter};
use scarb_ui::Ui;
use serde::{Deserialize, Serialize};
use smol_str::SmolStr;
use starknet::core::types::contract::SierraClass;
use starknet::core::types::Felt;
use tracing::{trace, trace_span};

use crate::aux_data::{AuxDataTrait, ContractAuxData, DojoAuxData, EventAuxData, ModelAuxData};
use crate::compiler::manifest::{
    AbstractBaseManifest, ContractManifest, EventManifest, ModelManifest, StarknetContractManifest,
};
use crate::scarb_extensions::{ProfileSpec, WorkspaceExt};
use crate::{
    BASE_CONTRACT_TAG, BASE_QUALIFIED_PATH, CAIRO_PATH_SEPARATOR, CONTRACTS_DIR, EVENTS_DIR,
    MODELS_DIR, RESOURCE_METADATA_QUALIFIED_PATH, WORLD_CONTRACT_TAG, WORLD_QUALIFIED_PATH,
};

use super::artifact_manager::{ArtifactManager, CompiledArtifact};
use super::contract_selector::ContractSelector;
use super::manifest::FromAuxDataTrait;
use super::scarb_internal;
use super::scarb_internal::debug::SierraToCairoDebugInfo;
use super::version::check_package_dojo_version;

#[derive(Debug, Default)]
pub struct DojoCompiler {
    /// Output the debug information of the compiled Sierra contracts.
    ///
    /// Mainly used for the Walnut debugger integration. It is used
    /// internally by Walnut to build the Dojo project with the Sierra
    /// debug information. This flag has no use outside of that.
    output_debug_info: bool,
}

impl DojoCompiler {
    pub fn new(output_debug_info: bool) -> Self {
        Self { output_debug_info }
    }

    pub fn compile_workspace(
        config: &Config,
        packages_filter: Option<PackagesFilter>,
        features: FeaturesSpec,
    ) -> Result<()> {
        let ws = scarb::ops::read_workspace(config.manifest_path(), config)?;

        let packages: Vec<Package> = if let Some(filter) = packages_filter {
            filter.match_many(&ws)?.into_iter().collect()
        } else {
            ws.members().collect()
        };

        for p in &packages {
            check_package_dojo_version(&ws, p)?;
        }

        ws.profile_check()?;

        DojoCompiler::clean(config, ProfileSpec::WorkspaceCurrent, true)?;

        trace!(?packages);

        let compile_info = scarb_internal::compile_workspace(
            config,
            CompileOpts {
                include_target_names: vec![],
                include_target_kinds: vec![],
                exclude_target_kinds: vec![TargetKind::TEST],
                features: features.try_into()?,
            },
            packages.iter().map(|p| p.id).collect(),
        )?;

        trace!(?compile_info, "Compiled workspace.");

        Ok(())
    }

    pub fn clean(
        config: &Config,
        profile_spec: ProfileSpec,
        remove_base_manifests: bool,
    ) -> Result<()> {
        let ws = scarb::ops::read_workspace(config.manifest_path(), config)?;

        ws.profile_check()?;

        let profile_name = ws
            .current_profile()
            .expect("Scarb profile is expected.")
            .to_string();

        trace!(
            profile = profile_name,
            ?profile_spec,
            remove_base_manifests,
            "Cleaning dojo compiler artifacts."
        );

        // Ignore fails to remove the directories as it might not exist.
        match profile_spec {
            ProfileSpec::All => {
                let target_dir = ws.target_dir();
                let _ = fs::remove_dir_all(target_dir.to_string());

                if remove_base_manifests {
                    let manifest_dir = ws.dojo_manifests_dir();
                    let _ = fs::remove_dir_all(manifest_dir.to_string());
                }
            }
            ProfileSpec::WorkspaceCurrent => {
                let target_dir_profile = ws.target_dir_profile();
                let _ = fs::remove_dir_all(target_dir_profile.to_string());

                if remove_base_manifests {
                    let manifest_dir_profile = ws.dojo_base_manfiests_dir_profile();
                    let _ = fs::remove_dir_all(manifest_dir_profile.to_string());
                }
            }
        }

        Ok(())
    }
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub struct Props {
    pub build_external_contracts: Option<Vec<ContractSelector>>,
}

impl Props {
    /// Verifies the props are correct.
    pub fn verify(&self) -> Result<()> {
        if let Some(external_contracts) = self.build_external_contracts.clone() {
            for selector in external_contracts.iter() {
                selector.is_valid()?;
            }
        }

        Ok(())
    }
}

impl Compiler for DojoCompiler {
    fn target_kind(&self) -> TargetKind {
        TargetKind::new("dojo")
    }

    fn compile(
        &self,
        unit: CairoCompilationUnit,
        db: &mut RootDatabase,
        ws: &Workspace<'_>,
    ) -> Result<()> {
        let props: Props = unit.main_component().target_props()?;
        props.verify()?;

        let main_crate_ids = collect_main_crate_ids(&unit, db, true);
        let compiler_config = build_compiler_config(&unit, &main_crate_ids, ws);

        trace!(unit = %unit.name(), ?props, "Compiling unit dojo compiler.");

        let contracts = find_project_contracts(
            db,
            main_crate_ids.clone(),
            props.build_external_contracts.clone(),
            &ws.config().ui(),
        )?;

        let artifact_manager =
            compile_contracts(db, &contracts, compiler_config, &ws, self.output_debug_info)?;

        let aux_data = DojoAuxData::from_crates(&main_crate_ids, db);

        let mut base_manifest = AbstractBaseManifest::new(ws);

        // Combine the aux data info about the contracts with the artifact data
        // to create the manifests.
        let contracts = write_dojo_element_artifacts::<ContractAuxData, ContractManifest>(
            &artifact_manager,
            &aux_data.contracts,
            CONTRACTS_DIR,
        )?;
        let models = write_dojo_element_artifacts::<ModelAuxData, ModelManifest>(
            &artifact_manager,
            &aux_data.models,
            MODELS_DIR,
        )?;
        let events = write_dojo_element_artifacts::<EventAuxData, EventManifest>(
            &artifact_manager,
            &aux_data.events,
            EVENTS_DIR,
        )?;
        let (world, base, sn_contracts) =
            write_sn_contract_artifacts(&artifact_manager, &aux_data)?;

        base_manifest.world = world;
        base_manifest.base = base;
        base_manifest.contracts.extend(contracts);
        base_manifest.models.extend(models);
        base_manifest.events.extend(events);
        base_manifest.sn_contracts.extend(sn_contracts);

        base_manifest.write()?;

        // TODO: add a check to ensure all the artifacts have been processed?

        Ok(())
    }
}

/// Finds the contracts in the project.
///
/// First searches for internal contracts in the main crates.
/// Then searches for external contracts in the external crates.
fn find_project_contracts(
    db: &mut RootDatabase,
    main_crate_ids: Vec<CrateId>,
    external_contracts: Option<Vec<ContractSelector>>,
    ui: &Ui,
) -> Result<Vec<ContractDeclaration>> {
    let internal_contracts = {
        let _ = trace_span!("find_internal_contracts").enter();
        find_contracts(db, &main_crate_ids)
    };

    let external_contracts = if let Some(external_contracts) = external_contracts {
        let _ = trace_span!("find_external_contracts").enter();
        trace!(external_contracts = ?external_contracts, "External contracts selectors from manifest.");

        let crate_ids = collect_crates_ids_from_selectors(db, &external_contracts);

        let filtered_contracts: Vec<ContractDeclaration> = find_contracts(db, crate_ids.as_ref())
            .into_iter()
            .filter(|decl| {
                let contract_path = decl.module_id().full_path(db);
                external_contracts
                    .iter()
                    .any(|selector| selector.matches(&contract_path))
            })
            .collect::<Vec<ContractDeclaration>>();

        // Display warnings for external contracts that were not found, due to invalid paths
        // most of the time.
        external_contracts
            .iter()
            .filter(|selector| {
                !filtered_contracts.iter().any(|decl| {
                    let contract_path = decl.module_id().full_path(db);
                    selector.matches(&contract_path)
                })
            })
            .for_each(|selector| {
                let diagnostic = format!("No contract found for path `{}`.", selector.full_path());
                ui.warn(diagnostic);
            });

        filtered_contracts
    } else {
        trace!("No external contracts found in the manifest.");
        Vec::new()
    };

    let all_contracts: Vec<ContractDeclaration> = internal_contracts
        .into_iter()
        .chain(external_contracts)
        .collect();

    // Display contracts that were found.
    let contract_paths = all_contracts
        .iter()
        .map(|decl| decl.module_id().full_path(db))
        .collect::<Vec<_>>();

    trace!(contracts = ?contract_paths, "Collecting contracts eligible for compilation.");

    Ok(all_contracts)
}

/// Compiles the contracts.
fn compile_contracts<'w>(
    db: &mut RootDatabase,
    contracts: &[ContractDeclaration],
    compiler_config: CompilerConfig,
    ws: &'w Workspace<'w>,
    do_output_debug_info: bool,
) -> Result<ArtifactManager<'w>> {
    let contracts: Vec<&ContractDeclaration> = contracts.iter().collect::<Vec<_>>();

    let classes = {
        let _ = trace_span!("compile_starknet").enter();
        compile_prepared_db(db, &contracts, compiler_config)?
    };

    let debug_info_classes: Vec<Option<SierraToCairoDebugInfo>> = if do_output_debug_info {
        let debug_classes =
            scarb_internal::debug::compile_prepared_db_to_debug_info(db, &contracts)?;

        debug_classes
            .into_iter()
            .map(|d| {
                Some(scarb_internal::debug::get_sierra_to_cairo_debug_info(
                    &d, db,
                ))
            })
            .collect()
    } else {
        vec![None; contracts.len()]
    };

    let mut artifact_manager = ArtifactManager::new(ws);
    let list_selector = ListSelector::default();

    for (decl, contract_class, debug_info) in izip!(contracts, classes, debug_info_classes) {
        let contract_name = decl.submodule_id.name(db.upcast_mut());
        // note that the qualified path is in snake case while
        // the `full_path()` method of StructId uses the original struct name case.
        // (see in `get_dojo_model_artifacts`)
        let qualified_path = decl.module_id().full_path(db.upcast_mut());

        match contract_class.validate_version_compatible(list_selector.clone()) {
            Ok(()) => {}
            Err(AllowedLibfuncsError::UnsupportedLibfunc {
                invalid_libfunc,
                allowed_libfuncs_list_name: _,
            }) => {
                let diagnostic = format! {r#"
                    Contract `{contract_name}` ({qualified_path}) includes `{invalid_libfunc}` function that is not allowed in the default libfuncs for public Starknet networks (mainnet, sepolia).
                    It will work on Katana, but don't forget to remove it before deploying on a public Starknet network.
                "#};

                ws.config().ui().warn(diagnostic);
            }
            Err(e) => {
                return Err(e).with_context(|| {
                    format!(
                        "Failed to check allowed libfuncs for contract: {}",
                        contract_name
                    )
                });
            }
        }

        let class_hash =
            compute_class_hash_of_contract_class(&contract_class).with_context(|| {
                format!(
                    "problem computing class hash for contract `{}`",
                    qualified_path.clone()
                )
            })?;

        artifact_manager.add_artifact(
            qualified_path,
            CompiledArtifact {
                class_hash,
                contract_class: Rc::new(contract_class),
                debug_info: debug_info.map(Rc::new),
            },
        );
    }

    Ok(artifact_manager)
}

/// Computes the class hash of a contract class.
fn compute_class_hash_of_contract_class(class: &ContractClass) -> Result<Felt> {
    let class_str = serde_json::to_string(&class)?;
    let sierra_class = serde_json::from_str::<SierraClass>(&class_str)
        .map_err(|e| anyhow!("error parsing Sierra class: {e}"))?;
    sierra_class
        .class_hash()
        .map_err(|e| anyhow!("problem hashing sierra contract: {e}"))
}

/// Collects the main crate ids for Dojo including the core crates.
pub fn collect_main_crate_ids(
    unit: &CairoCompilationUnit,
    db: &RootDatabase,
    with_dojo_core: bool,
) -> Vec<CrateId> {
    let mut main_crate_ids = scarb::compiler::helpers::collect_main_crate_ids(&unit, db);

    if unit.main_package_id.name.to_string() != "dojo" && with_dojo_core {
        let core_crate_ids: Vec<CrateId> = collect_crates_ids_from_selectors(
            db,
            &[
                ContractSelector::new(WORLD_QUALIFIED_PATH.to_string()),
                ContractSelector::new(BASE_QUALIFIED_PATH.to_string()),
            ],
        );

        main_crate_ids.extend(core_crate_ids);
    }

    main_crate_ids
}

/// Collects the crate ids containing the given contract selectors.
pub fn collect_crates_ids_from_selectors(
    db: &RootDatabase,
    contract_selectors: &[ContractSelector],
) -> Vec<CrateId> {
    contract_selectors
        .iter()
        .map(|selector| selector.package().into())
        .unique()
        .map(|package_name: SmolStr| db.intern_crate(CrateLongId::Real(package_name)))
        .collect::<Vec<_>>()
}

/// Writes the dojo elements artifacts to the target directory and returns the element manifests.
fn write_dojo_element_artifacts<T: AuxDataTrait, U: FromAuxDataTrait<T>>(
    artifact_manager: &ArtifactManager,
    aux_data: &HashMap<String, T>,
    element_dir: &str,
) -> Result<Vec<U>> {
    let mut elements = Vec::new();

    for (qualified_path, aux_data) in aux_data.iter() {
        let filename = naming::get_filename_from_tag(&aux_data.tag());

        let target_dir = artifact_manager
            .workspace()
            .target_dir_profile()
            .child(element_dir);

        artifact_manager.write_sierra_class(qualified_path, &target_dir, &filename)?;
        elements.push(U::from_aux_data(
            aux_data,
            artifact_manager.get_class_hash(qualified_path)?,
            qualified_path,
        ));
    }

    Ok(elements)
}

/// Writes the starknet contracts artifacts to the target directory and returns the starknet contract manifests.
///
/// Returns a tuple with the world contract manifest, the base contract manifest and the other starknet contract manifests.
fn write_sn_contract_artifacts(
    artifact_manager: &ArtifactManager,
    aux_data: &DojoAuxData,
) -> Result<(
    StarknetContractManifest,
    StarknetContractManifest,
    Vec<StarknetContractManifest>,
)> {
    let mut contracts = Vec::new();
    let mut world = StarknetContractManifest::default();
    let mut base = StarknetContractManifest::default();

    for (qualified_path, contract_name) in aux_data.sn_contracts.iter() {
        let target_dir = artifact_manager.workspace().target_dir_profile();

        let file_name = match qualified_path.as_str() {
            WORLD_QUALIFIED_PATH => {
                let name = WORLD_CONTRACT_TAG.to_string();

                world = StarknetContractManifest {
                    class_hash: artifact_manager.get_class_hash(qualified_path)?,
                    qualified_path: qualified_path.to_string(),
                    name: name.clone(),
                };

                name
            }
            BASE_QUALIFIED_PATH => {
                let name = BASE_CONTRACT_TAG.to_string();

                base = StarknetContractManifest {
                    class_hash: artifact_manager.get_class_hash(qualified_path)?,
                    qualified_path: qualified_path.to_string(),
                    name: name.clone(),
                };

                name
            }
            RESOURCE_METADATA_QUALIFIED_PATH => {
                // Skip this dojo contract as not used in the migration process.
                continue;
            }
            _ => {
                let file_name = qualified_path.replace(CAIRO_PATH_SEPARATOR, "_");

                contracts.push(StarknetContractManifest {
                    class_hash: artifact_manager.get_class_hash(qualified_path)?,
                    qualified_path: qualified_path.to_string(),
                    name: contract_name.clone(),
                });

                file_name
            }
        };

        artifact_manager.write_sierra_class(qualified_path, &target_dir, &file_name)?;
    }

    Ok((world, base, contracts))
}
