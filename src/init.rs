use std::env;
use std::fs;
use std::path::PathBuf;

use super::{Config, CliError, LalResult};
use core::manifest::*;


/// Helper to print the dependencies from the manifest
pub fn dep_list(mf: &Manifest, core: bool) -> LalResult<()> {
    let deps = if core { mf.dependencies.clone() } else { mf.all_dependencies() };
    for k in deps.keys() {
        println!("{}", k);
    }
    Ok(())
}


fn create_lal_subdir(pwd: &PathBuf) -> LalResult<()> {
    let loc = pwd.join(".lal");
    if !loc.is_dir() {
        fs::create_dir(&loc)?
    }
    Ok(())
}

/// Generates a blank manifest in the current directory
///
/// This will use the directory name as the assumed default component name
/// Then fill in the blanks as best as possible.
///
/// The function will not overwrite an existing `manifest.json`,
/// unless the `force` bool is set.
pub fn init(cfg: &Config, force: bool, env: &str) -> LalResult<()> {
    cfg.get_container(env.into())?;

    let pwd = env::current_dir()?;
    let last_comp = pwd.components().last().unwrap(); // std::path::Component
    let dirname = last_comp.as_os_str().to_str().unwrap();

    let mpath = ManifestLocation::identify(&pwd);
    if !force && mpath.is_ok() {
        return Err(CliError::ManifestExists);
    }

    // we are allowed to overwrite or write a new manifest if we are here
    // always create new manifests in new default location
    create_lal_subdir(&pwd)?; // create the `.lal` subdir if it's not there already
    Manifest::new(dirname, env, ManifestLocation::default().as_path(&pwd)).write()?;

    // if the manifest already existed, warn about this now being placed elsewhere
    if let Ok(ManifestLocation::RepoRoot) = mpath {
        warn!("Created manifest in new location under .lal");
        warn!("Please delete the old manifest - it will not be read anymore");
    }

    Ok(())
}
