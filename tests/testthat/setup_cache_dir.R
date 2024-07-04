R_USER_CACHE_DIR<-tempfile()
dir.create(R_USER_CACHE_DIR)
Sys.setenv("R_USER_CACHE_DIR"=R_USER_CACHE_DIR)
r_version <- R.Version()$version.string
is_rdevel <- grepl("unstable", r_version)
