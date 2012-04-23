require 'opencv-ffi/core/types'
require 'opencv-ffi-wrappers/core'
require 'opencv-ffi-wrappers/misc'

require 'matrix'


# Monkey with Matrix and Vector's coercion functions
class Vector
  alias :coerce_orig :coerce
  def coerce(other)
    case other
    when CvMat
      nil
    else
      coerce_orig(other)
    end
  end
end

module CVFFI

  module CvMatFunctions
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    # This is the somewhat funny Matrix format for coerce
    # which returns the template class as well as the coerced version
    # of the matrix
    def coerce( other )
            case other
                     when Matrix 
                       [other, to_Matrix]
                     when Vector 
                       [other, to_Vector]
                     else
                       raise TypeError, "#{self.class} can't be coerced into #{other.class}, fool"
                     end
          end


    def to_CvMat( opt = {} )
      if opt[:type]
        raise "Need to convert CvMat types" if opt[:type] != type
      end
      self
    end

    def to_Mat
      CVFFI::Mat.new( self )
    end

    def to_Matrix
      Matrix.build( height, width ) { |i,j|
        at_f(i,j)
      }
    end

    def to_ScalarMatrix
      ScalarMatrix.rows Array.new( height ) { |y|
        Array.new( width ) { |x|
          d = CVFFI::cvGet2D( self, y,x )
          d.w
        }
      }
    end

    def to_Vector
      to_Matrix if height > 1 and width > 1
      a = []
      if height == 1
        a = Array.new( width ) { |i| at_f(0,i) } 
      else
        a = Array.new( height ) { |i| at_f(i,0) }
      end
      Vector[*a]
    end

    def to_a
      to_Vector.to_a
    end

    # This is somewhat awkward because the FFI::Struct-iness of
    # CvMat uses the Array-like API calls (at, [], size, etc)
    def at_f(i,j)
      CVFFI::cvGetReal2D( self, i, j )
    end

    def set_f( i,j, f )
      CVFFI::cvSetReal2D( self, i, j, f )
    end

    def at_scalar(i,j)
      CVFFI::cvGet2D( self, i.to_i, j.to_i )
    end

    def set_scalar( i,j, f )
      CVFFI::cvSet2D( self, i, j, f )
    end

    def clone
      CVFFI::cvCloneMat( self )
    end

    def mat_size
      CVFFI::CvSize.new( :width => self.width, :height => self.height ) 
    end
    alias :image_size :mat_size

    def twin
      CVFFI::cvCreateMat( self.height, self.width, self.type )
    end

    def transpose
      a = CVFFI::cvCreateMat( self.width, self.height, self.type )
      CVFFI::cvTranspose( self, a )
      a
    end

    def zero
      CVFFI::cvSetZero( self )
    end

    def split
      out = Array.new( channels ) { |i| CVFFI::cvCreateMat( self.height, self.width, self.depth ) }
      
      CVFFI::cvSplit( self, out[0], out[1], out[2], out[3] );
      out[0,channels]
    end

    def print( opts = {} )
      CVFFI::print_matrix( self, opts )
    end

    def channels
      CVFFI::matChannels( self )
    end

    def depth
      CVFFI::matDepth( self )
    end

    module ClassMethods 
      def eye( x, type = :CV_32F )
        a = CVFFI::cvCreateMat( x, x, type )
        CVFFI::cvSetIdentity( a, CVFFI::CvScalar.new( :w => 1, :x => 1, :y => 1, :z => 1 ) )
        a
      end

      def print( m, opts = {} )
        CVFFI::print_matrix( m, opts )
      end

    end


  end

  class CvMat
    include CvMatFunctions
  end
  
  class Mat
    include CvMatFunctions
    include Enumerable

    def self.wrap_function( s )
      class_eval "def #{s}( *args ); Mat.new( mat.#{s}(*args) ); end"
    end

    def self.pass_function( s )
      class_eval "def #{s}( *args ); mat.#{s}(*args); end"
    end

    [ :twin, :clone ].each { |f| wrap_function f }
    
    attr_accessor :mat
    #attr_accessor :type
    
    def type; CVFFI::matType(mat); end

    def initialize( *args )
      a1,a2,a3 = *args
      case a1
      when Mat
        # Copy constructor
        @mat = a1.mat
      when CvMat
        @mat = a1
      when Size
        opts = a2 || {}
        opts = { type: opts } if opts.is_a? Symbol
        doZero = opts[:zero] || true
        type = opts[:type] || :CV_32F
        @mat = CVFFI::cvCreateMat( args[0].height, args[0].width, type )
        mat.zero if doZero
      else
        rows,cols,opts = a1,a2,a3
        opts ||= {}
        opts = { type: opts } if opts.is_a? Symbol
        doZero = opts[:zero] || true
        type = opts[:type] || :CV_32F
        @mat = CVFFI::cvCreateMat( rows, cols, type )

        mat.zero if doZero
      end

      if block_given?
      rows.times { |i|
        cols.times { |j|
          set(i,j, yield(i,j) )
        }
      }
      end

    end

    def at=(i,j,v)
      if type == :CV_32F
        mat.set_f( i,j, v)
      else
        mat.set_scalar( i,j, v) # CVFFI::CvScalar.new( { w: v, x: v, y: v, z: v } ) )
      end
    end
    alias :[]= :at=
    alias :set :at=

    def at(i,j)
      if type == :CV_32F
        mat.at_f( i,j)
      else
        mat.at_scalar( i,j )
      end
    end
    alias :[] :at

    def each( &blk )
      each_with_indices { |v,i,j| blk.call( v ) }
    end

    def each_with_indices( &blk )
      height.times { |i|
        width.times { |j|
          blk.call at(i,j), i, j 
        }
      }
    end


    [ :height, :width ].each { |f| pass_function f }

    def self.build( rows, cols, opts = {}, &blk )
      Mat.new( rows, cols, opts ) { |i,j| blk.call(i,j) }
    end

    def self.eye( size, opts = {} )
      m = Mat.new( size,size,opts )
      size.times { |i| m[i,i] = 1 }
      m
    end

    def self.rows( r, opts = {} )
      height = r.length
      width = r[0].length

      Mat.build( height, width, opts ) { |i,j|
        r[i][j]
      }
    end

    def mean( opts = {} )
      mask = opts[:mask] || nil

      # "cast" mask to 8U
      if mask and mask.type != :CV_8U
        raise "Mask not same size as self" unless height == mask.height
        mm = mask
        mask = Mat.build( height, width, :CV_8U ) { |i,j|
          mm[i,j] > 0 ? 1 : 0
        }
      end

      CVFFI::avg( self, mask )
    end
  
    def mean_variance( opts = {} )
      mask = opts[:mask] || nil

      # "cast" mask to 8U
      if mask and mask.type != :CV_8U
        raise "Mask not same size as self" unless height == mask.height
        mm = mask
        mask = Mat.build( height, width, :CV_8U ) { |i,j|
          mm[i,j] > 0 ? 1 : 0
        }
      end

    mean,stddev = CVFFI::avgSdv( self, mask )
    [mean, stddev*stddev]
    end

    # Should impedence match Mat anywhere a CvMat * is required...
    # TODO: Figure out how to handler passing by_value
    def to_ptr
      @mat.pointer
    end

    def norm( b, type = :CV_L2 )
      CVFFI::cvNorm( self, b, type )
    end

    def l2distance(b); norm(b, :CV_L2 ); end

    def ==(b)
      return false if width != b.width or height != b.height or type != b.type

      cmpResult = Mat.new( height, width, :CV_8U )
      # Fills cmpResults with 1 for each element which is not equal
      CVFFI::cvCmp( self, b, cmpResult, :CV_CMP_NE )

      # If results are equal, cmpResult will be all zeros
      sum = CVFFI::cvSum( cmpResult )
      sum.w == 0
    end

    def save( fname )
      CVFFI::cvSaveImage( fname, to_CvMat )
    end

    def ensure_greyscale
      greyImg = CVFFI::cvCreateMat( height, width, :CV_8U )
      CVFFI::cvCvtColor( self.to_CvMat, greyImg, :CV_BGR2GRAY )
      Mat.new(greyImg)
    end

    def to_float
      float = CVFFI::cvCreateMat( height, width, :CV_32F )
      CVFFI::cvConvertScale( self.to_CvMat, float, 1, 0 )
      Mat.new( float )
    end

    def to_uint( scale = 1 )
      uint = CVFFI::cvCreateMat( height, width, :CV_8U )
      CVFFI::cvConvertScale( self.to_CvMat, uint, scale, 0 )
      Mat.new( uint )
    end


    def +(b)
      case b
      when Numeric
        other = CVFFI::Scalar.new( b,b,b,b )
        dest = twin
        CVFFI::cvAddS( self.to_CvMat, other.to_CvScalar, dest.to_CvMat, nil )
        dest
      when Mat, CvMat
        dest = twin
        CVFFI::cvAdd( self.to_CvMat, other.to_CvMat, dest.to_CvMat, nil )
        dest
      else
        raise "Don't know how to add #{b} to a Mat"
      end
    end

    def -(b)
      case b
      when Numeric
        other = CVFFI::Scalar.new( -b,-b,-b,-b )
        dest = twin
        CVFFI::cvAddS( self.to_CvMat, other.to_CvScalar, dest.to_CvMat, nil )
        dest
      when Mat, CvMat
        dest = twin
        CVFFI::cvSub( self.to_Cvmat, other.to_CvMat, dest.to_CvMat, nil )
        dest
      else
        raise "Don't know how to subtract #{b} from a Mat"
      end
    end

    def *(b)
      case b
      when Numeric
        scale_add( b, 0.0 )
      else 
        raise "Don't know how to handle multiplication of a Mat by a #{b.class}"
      end
    end

    def minMaxLoc
      case channels
      when 1
        CVFFI::minMaxLoc( self.to_CvMat )
      else
        split.map { |channel| CVFFI::minMaxLoc( channel.to_CvMat ) }.transpose
      end
    end

    def minMax
      (minMaxLoc)[0,2]
    end

    def max; min,max = minMax; max; end
    def min; min,max = minMax; min; end

    def scale_add( s, a )
      a = case a
          when Numeric
            adder = twin
            CVFFI::cvSet( adder.to_CvMat, 
                         CVFFI::Scalar.new( a,a,a,a ).to_CvScalar, nil )
            adder
          when Mat, CvMat
            a
          else
            raise "Don't know how to add #{a} to an array"
          end

      scalar = CVFFI::Scalar.new( s,s,s,s )
      dest = twin

      CVFFI::cvScaleAdd( self.to_CvMat, scalar.to_CvScalar, a.to_CvMat, dest )
      dest
    end
    alias :scaleAdd :scale_add

    def warp_perspective( m )
      dest = twin

      CVFFI::cvWarpPerspective( self.to_CvMat, dest.to_CvMat, m.to_CvMat )

      dest
    end

    def log
      dest = twin
      CVFFI::cvLog( self.to_CvMat, dest.to_CvMat )
      dest
    end

    def resize( size, interpolation = :CV_INTER_LINEAR )
      sz = CVFFI::Size.new( size )
      dest = CVFFI::Mat.new( sz,  {type: type} )

      CVFFI::cvResize( self.to_CvMat, dest.to_CvMat, interpolation ) 

      dest
    end

    def subRect( origin, size )
      o = CVFFI::Point.new( origin )
      sz = CVFFI::Size.new( size )

      rect = CVFFI::CvRect.new( x: o.x, y: o.y, width: size.width, height: size.height )
      dst = CVFFI::cvCreateMatHeader( size.width, size.height, :CV_32F )
      Mat.new( CVFFI::cvGetSubRect( self.to_CvMat, dst, rect ) )
    end

    alias :ensure_grayscale :ensure_greyscale
    alias :to_gray :ensure_greyscale
    alias :to_gray :ensure_greyscale


  end
end
