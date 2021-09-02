db_path <- file.path(Sys.getenv("RUNR_CWD"), "db")
record::open_db(db_path, create= if(!dir.exists(db_path)) TRUE)

argtracer::trace_args(code={
  .BODY.
})

record::size_db()
record::close_db()
