record::open_db(file.path(Sys.getenv("RUNR_CWD"), "db"), create=TRUE)

argtracer::trace_args(code={
  .BODY.
})

record::size_db()
record::close_db()
