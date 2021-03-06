
require '../mkrf-monkey'

# The compiler for availability checking must be specified as 'g++'
# otherwise it will use gcc and choke on Eigen
#
Mkrf::Generator.new('libcvffi_eigen', [ "*.cpp" ], { :compiler=>"g++"}) { |g|
  g.include_library 'stdc++'
  raise "Can't find 'opencv_core'" unless g.include_library 'opencv_core', 'main', "#{ENV['HOME']}/usr/lib"
  raise "Can't find #include<eigen3/Eigen/Core>" unless g.include_header  'eigen3/Eigen/Core', "#{ENV['HOME']}/usr/include"

  # This is awkward.  Eigen's unsupported directory references 
  # includes like  <Eigen/Core> -- but /usr/include/eigen3 isn't
  # in the default search path.
  g.cflags += "-I#{ENV['HOME']}/usr/include -I/usr/include/eigen3 -I/usr/local/include/eigen3 -I#{ENV['HOME']}/usr/include/eigen3"
}

