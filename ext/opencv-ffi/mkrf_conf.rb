require '../mkrf-monkey'

# The compiler for availability checking must be specified as 'g++'
# otherwise it will use gcc and choke on Eigen
#
Mkrf::Generator.new('libopencvffi', [ "*.cpp", "eigen/*.cpp", "fast/*.c" ], { :compiler=>"g++"}) { |g|
  g.include_library 'stdc++'
  raise "Can't find 'opencv_core'" unless g.include_library 'opencv_core', 'main', "#{ENV['HOME']}/usr/lib"
  g.include_header  'eigen3/Eigen/Core', "#{ENV['HOME']}/usr/include"
  g.cflags += "-I#{ENV['HOME']}/usr/include "
}

