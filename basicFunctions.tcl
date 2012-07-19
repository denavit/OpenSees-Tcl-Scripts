proc incr { varName {amount 1}} {
    # Example 7-6
    # Practical Programming in Tcl and Tk
    # Third Edition
    # Brent B. Welch
    upvar 1 $varName var
    if {[info exists var]} {
        set var [expr $var + $amount]
    } else {
        set var $amount
    }
    return $var
}

proc OpenSeesComposite::areaCircularSector { d R } {
    set theta [expr 2*acos(abs($d)/$R)]
    set area [expr 0.5*$R*$R*($theta-sin($theta))]
    return $area
}

proc OpenSeesComposite::centroidCircularSector { d R } {
    set theta [expr 2*acos(abs($d)/$R)]
    if {$d >= 0} {
        set sign +1
    } else {
        set sign -1
    }
    if {$theta == 0.0} {
        set centroid $R
    } else {
        set centroid [expr (4*$R*pow(sin(0.5*$theta),3))/(3*($theta-sin($theta)))]
    }
    #puts "centroid: $centroid d: $d R: $R sign: $sign"
    set centroid [expr $sign*$centroid]
    return $centroid
}

proc OpenSeesComposite::nShapesCentroid {data} {
    set xArea 0.0
    set yArea 0.0
    set area 0.0
    set numShapes [expr [llength $data]/3]
    for {set i 1} {$i <= $numShapes} {incr i} {
        set x [lindex $data [expr 3*($i-1)+0]]
        set y [lindex $data [expr 3*($i-1)+1]]
        set a [lindex $data [expr 3*($i-1)+2]]
        incr xArea [expr $x*$a]
        incr yArea [expr $y*$a]
        incr area $a
    }
    return [list [expr $xArea/$area] [expr $yArea/$area] $area]
}

proc OpenSeesComposite::patchRect2d { matTag nf width startHeight endHeight } {
    # ###################################################################
    # patchRect2d $matTag $nf $width $startHeight $endHeight
    # ###################################################################
    # create a quadrilateral patch suitable for two dimensional analyses
    # all fibers are placed on the Z axis
    #
    #
    if { $startHeight >= $endHeight } {
        puts "Warning: patchRect2d is creating fibers with a negative area"
    }
    set nf [expr int($nf)]
    set halfWidth [expr $width/2]
    patch quad $matTag $nf 1 $startHeight -$halfWidth $endHeight -$halfWidth $endHeight $halfWidth $startHeight $halfWidth
}

proc OpenSeesComposite::patchHalfCircTube2d { matTag nf center side D t } {
    # ###################################################################
    # patchHalfCircTube2d $matTag $nf $center $side $D $t
    # ###################################################################
    # creates a set of fibers to describe half a circular tube. The fibers
    # are suitable for two dimensional analyses since all fibers are placed
    # on the Z axis
    #
    # Input Parameters:
    # matTag - integer tag for uniaxialMaterial
    # nf - number of fibers along the height of the section
    # center - location on the y axis of the center of the tube
    # side - side of tube to create
    #    - top
    #    - bottom
    # D - diameter of the tube
    # t - thickness of the tube

    # Make sure things are doubles
    set center  [expr double($center)]
    set D       [expr double($D)]
    set t       [expr double($t)]

    # Check input data
    if { [string equal $side top] == 0 && [string equal $side bottom] == 0 } {
        error "Error - patchHalfCircTube2d: side should not be either 'top' or 'bottom'"
    }

    if { $D <= 0.0 } {
        error "Error - patchHalfCircTube2d: D should be input as a posititve value"
    }

    if { $t <= 0.0 } {
        error "Error - patchHalfCircTube2d: t should be input as a posititve value"
    }

    if { $t > [expr 0.5*$D]} {
        error "Error - patchHalfCircTube2d: t is too large compared to D"
    }

    # Computed parameters
    if { [string equal $side top] == 1 } {
        set dir  1.0
    } else {
        set dir -1.0
    }
    set D       [expr abs($D)]
    set ro      [expr $D/2]
    set ri      [expr $D/2-$t]
    set yeach   [expr $ro/double($nf)]

    # Create fibers
    for {set i 1} {$i <= $nf} {incr i} {

        set yfar  [expr $ro - ($i-1)*$yeach]
        set ynear [expr $ro - ($i)*$yeach]
        if { $ynear < 0.0 } {
            set ynear 0.0
        }

        set data [list 0.0 [centroidCircularSector $yfar $ro] [expr -1*[areaCircularSector $yfar $ro]]]
        lappend data 0.0 [centroidCircularSector $ynear $ro] [areaCircularSector $ynear $ro]
        if {$yfar >= $ri && $ynear >= $ri} {

        } elseif {$yfar >= $ri && $ynear < $ri} {
            lappend data 0.0 [centroidCircularSector $ynear $ri] [expr -1*[areaCircularSector $ynear $ri]]
        } else {
            lappend data 0.0 [centroidCircularSector $yfar $ri] [areaCircularSector $yfar $ri]
            lappend data 0.0 [centroidCircularSector $ynear $ri] [expr -1*[areaCircularSector $ynear $ri]]
        }
        set thisStrip [nShapesCentroid $data]
        set thisArea [lindex $thisStrip 2]
        set thisCentroid [lindex $thisStrip 1]

        fiber [expr $center+$dir*$thisCentroid] 0.0 $thisArea $matTag
    }
}

proc OpenSeesComposite::fourFiberSectionGJ { secID matID area Iy Iz GJ } {
  # ###################################################################
  # fourFiberSectionGJ $secID $matID $area $Iy $Iz $GJ
  # ###################################################################
  # create a fiber section with four fibers with desired section properties
  #
  # Input Parameters:
  # secID - section ID number
  #    - "noSection" defines just the fibers, used when the section has already been defined
  # matID - material ID number
  # A  = desired total cross sectional area of section
  # Iy = desired moment of intera about the Y axis of the section
  # Iz = desired moment of intera about the Z axis of the section
  # GJ = desired torsional stiffness of the section (not used if "noSection" option is selected)

  # Define Section by calling itself with secID = noSection
  if { [string compare -nocase $secID "noSection"] != 0 } {
    section fiberSec $secID -GJ $GJ {
      fourFiberSectionGJ noSection $matID $area $Iy $Iz $GJ
    }
    return
  }

  # Make sure things are doubles
  set area  [expr double($area)]
  set Iy    [expr double($Iy)]
  set Iz    [expr double($Iz)]
  set GJ    [expr double($GJ)]

  # Compute Fiber Information
  set fiberA [expr 0.25*$area]
  set fiberZ [expr pow($Iy/$area,0.5)]
  set fiberY [expr pow($Iz/$area,0.5)]

  # Define Fibers
  fiber  $fiberY  $fiberZ $fiberA $matID
  fiber  $fiberY -$fiberZ $fiberA $matID
  fiber -$fiberY  $fiberZ $fiberA $matID
  fiber -$fiberY -$fiberZ $fiberA $matID
}

proc OpenSeesComposite::twoFiberSection { secID matID area I } {
  # ###################################################################
  # twoFiberSection $secID $matID $area $I
  # ###################################################################
  # create a fiber section with two fibers with desired section properties
  #
  # Input Parameters:
  # secID - section ID number
  #    - "noSection" defines just the fibers, used when the section has already been defined
  # matID - material ID number
  # A  = desired total cross sectional area of section
  # I = desired moment of intera

  # Define Section by calling itself with secID = noSection
  if { [string compare -nocase $secID "noSection"] != 0 } {
    section fiberSec $secID {
      twoFiberSection noSection $matID $area $I
    }
    return
  }

  # Make sure things are doubles
  set area  [expr double($area)]
  set I     [expr double($I)]

  # Compute Fiber Information
  set fiberA [expr 0.5*$area]
  set fiberY [expr pow($I/$area,0.5)]

  # Define Fibers
  fiber  $fiberY 0.0 $fiberA $matID
  fiber -$fiberY 0.0 $fiberA $matID
}

proc OpenSeesComposite::eigenRecorder { fileName numEigenValues {type -generalized} {solver -genBandArpack} } {
    # ###################################################################
    # eigenRecorder $fileName $numEigenValues <$type> <$solver>
    # ###################################################################
    # write to eigenvalues to a file, returns the lowest eigen value
    #
    # Input Parameters:
    # fileName - name of file you wish to write to
    # numEigenValues - number of eigen values you wish to print
    # type - type of eigen analysis (default: -generalized)
    # solver - solver to be used (default: -genBandArpack)

    # Perform Eigen Analysis
    set eigenList [eigen $type $solver $numEigenValues]

    # Write to file
    set fileId [open $fileName a]
    puts $fileId "[getTime] $eigenList"
    close $fileId

    # Return the lowest eigen value
    return [lindex $eigenList 0]
}

proc OpenSeesComposite::updateRayleighDamping { modeA ratioA modeB ratioB } {
    # ###################################################################
    # updateRayleighDamping $modeA $ratioA $modeB $ratioB
    # ###################################################################
    # Runs an eigenvalue analysis and set proportional damping based on
    # the current state of the structure
    #
    # Input Parameters:
    # modeA, modeB - modes that will have perscribed damping ratios
    # ratioA, ratioB - damping ratios perscribed at the specified modes

    # Get natural frequencies at the desired modes
    if { $modeA > $modeB } {
        set maxMode $modeA
    } else {
        set maxMode $modeB
    }

    set eigs    [eigen $maxMode]
    set freqA   [expr sqrt([lindex $eigs [expr $modeA-1]])]
    set freqB   [expr sqrt([lindex $eigs [expr $modeB-1]])]

    # Compute the damping factors
    set tempVal [expr 2.0/($freqA*$freqA-$freqB*$freqB)]
    set aM      [expr $tempVal*$freqA*$freqB*($ratioB*$freqA-$ratioA*$freqB)]
    set aK      [expr $tempVal*($ratioA*$freqA-$ratioB*$freqB)]

    # Set the damping
    rayleigh $aM 0.0 0.0 $aK
}

proc OpenSeesComposite::printNodeCoordinates { filename } {
    # ###################################################################
    # printNodeCoordinates $filename
    # ###################################################################
    # Print coordinates of all of the nodes to a file
    #
    # Input Parameters:
    # filename - name of the file to which the node coordinates will be written

    # Open File
    set fileId [open $filename "w"]

    # Loop through nodes and print data to file
    set nodeTags [getNodeTags]
    for {set i 0} {$i < [llength $nodeTags]} {incr i} {
        set nodeTag [lindex $nodeTags $i]
        puts $fileId "$nodeTag [nodeCoord $nodeTag]"
    }

    # Close File
    close $fileId
}


proc OpenSeesComposite::simplePanelZoneMaterial {matTag Vu Ke {h 1}} {
  # ###################################################################
  # simplePanelZoneMaterial $matTag $Vu $Ke $h
  # ###################################################################
  # Define a simple tri-linear uniaxialMaterial for panel zones based on
  # the shear strength, elastic stiffness, and height of the panel zone.
  #
  # Input Parameters:
  # matTag - integer tag for the uniaxialMaterial
  # Vu     - panel zone shear strength
  # Ke     - panel zone shear elastic stiffness
  # h      - height of the panel zone, if defined then a moment relation
  #          suitable for the rotational spring of a parallelogram model
  #          is given, otherwise a shear relation is given.

  set Vu [expr double($Vu)]
  set Ke [expr double($Ke)]
  set h  [expr double($h)]

  set My [expr 0.6*$Vu*$h]
  set Qy [expr 0.6*$Vu/$Ke]
  set Mu [expr $Vu*$h]
  set Qu [expr 2.6*$Vu/$Ke]
  set Ku [expr 0.01*$Ke*$h]

  # Define material
  uniaxialMaterial multiSurfaceKinematicHardening $matTag \
    -StressStrainSymmetric $My $Qy $Mu $Qu $Ku
}