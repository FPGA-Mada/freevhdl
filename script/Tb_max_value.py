from vunit import VUnit

# Create VUnit instance from command line arguments
vu = VUnit.from_argv()

# Add a library
lib = vu.add_library("lib")

# Add source files
lib.add_source_files("src/library/math_utils.vhd")
lib.add_source_files("src/base/max_value.vhd")



# Add testbench files
lib.add_source_files("tb/base/Tb_max_value.vhd")
# Run VUnit
vu.main()