{
  projectRootFile = "flake.lock";
  programs = {
    deadnix.enable = true;
    nixpkgs-fmt.enable = true;
    stylua. enable = true;
  };
}
