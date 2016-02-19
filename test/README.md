
# Test Source for MRO
- entryPoints contains the executables that are run in the build gate
  tests and extended tests.  These executables are run by the workflow
  described in branch.json for the gated checkin. They are expected to
  clean up after themselves, drop their artifacts in the directory in
  which they run and return 0 if all tests run, non zero otherwise and
  write "FAILED!!" to standard output if some test failed.
- IOQR contains the "Installation and Operational Qualifier for R"
  package: it contains a set of tests to use to ensure R is fully
  functional.


