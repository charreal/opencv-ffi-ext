
require 'opencv-ffi-wrappers'
require 'opencv-ffi-wrappers/matrix'


module CVFFI

  module Calib3d
    extend NiceFFI::Library

    libs_dir = File.dirname(__FILE__) + "/../../../ext/opencv-ffi/"
    pathset = NiceFFI::PathSet::DEFAULT.prepend( libs_dir )
    load_library("cvffi", pathset)

    class FEstimatorParams < CVFFI::Params
      param :max_iters, 2000
      param :outlier_threshold, 3
      param :confidence, 0.99
      param :method, :CV_FM_RANSAC
    end

    #
    # Just for clarity this is my "hacked" version of the 
    # stock CV cvEstimateFundamentalMat.  Should expect 
    # further deviations as time goes on.
    #
    attach_function :cvEstimateFundamental, [ :pointer, :pointer, :pointer, 
      :int, :double, :double, :int, :pointer ], :int

    def self.estimateFundamental( points1, points2, params )

      # There's a bit of a snarl in the logic in cvEstimateFundamental 
      # (and cvEstimateFundamentalMat) ... you can request the 7-point
      # algorithm but it will only do it if you specify exactly 
      # 7 elements of points1.  

      count = [ points1.rows, points1.cols ].max
      fundamental = case count
                    when 7
                      params.method = :CV_FM_7POINT
                      CVFFI::cvCreateMat( 9, 3, :CV_64F )
                    else
                      CVFFI::cvCreateMat( 3,3, :CV_64F )
                    end
      status = CVFFI::cvCreateMat( points1.height, 1, :CV_8U )

      ret = cvEstimateFundamental( points1, points2, fundamental, 
                                   CvRansacMethod[ params.method ], params.outlier_threshold, params.confidence, params.max_iters, status )

      if ret > 0
        case count
        when 7
          # In case of 7 point algorithm, should expect 3 answers
          # stacked up in a 9x3 matrix.  Here's one way to do it.
          m = fundamental.to_Matrix.row_vectors
          Array.new(3) { |i|
            as_mat = Matrix.rows( m.shift(3) )
            Fundamental.new( as_mat.to_Mat( :type => :CV_64F ), status, ret )
          }

        else
        Fundamental.new( Mat.new(fundamental), status, ret )
        end
      else
        nil
      end

    end

    # Will run 7-point if there are only 7 data points, otherwise
    # will run 8-point ... never RANSAC or LMedS
    def self.fundamentalKernel( points1, points2 )
      # All of the other params shoudl be irrelevant
      # for the 7- and 8-point algorithms
      params = FEstimatorParams.new( :method => :CV_FM_8POINT )
      estimateFundamental( points1, points2, params )
    end


    ## Just a thin wrapper until I start monkeying with the Homography
    #  estimator as well.
    def self.estimateHomography( points1, points2, params )
      puts "Running my homography calculation."
      CVFFI::findHomography( points1, points2, CvRansacMethod[ params.method ], params.outlier_threshold )
    end
  end
end