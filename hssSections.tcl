proc OpenSeesComposite::recthssSection { secID startMatID nf1 nf2 units D B t Fy Fu Es args} {
  # ###################################################################
  # recthssSection $secID $startMatID $nf1 $nf2 $units $D $B $t $Fy $Fu $Es
  # ###################################################################
  # tcl procedure for creating a steel reinforced concrete fiber section
  #
  # input parameters:
  # secID - section ID number
  # startMatID - starting number for the material that will be defined
  # nf1 = number of fibers along the primary bending axis (strong axis for 3d)
  # nf2 = number of fibers along the secondary bending axis
  #    - strong = creates a 2d section for strong axis bending
  #    - weak   = creates a 2d section for weak axis bending
  # units - unit system
  #    US = United States customary units (i.e., kips, inches, ksi)
  #    SI = International System of Units (i.e., N, mm, MPa)
  # D  = depth
  # B = width
  # t = thickness
  # Fy = yield strength of the steel section
  # Fu = ultimate strength of the steel section
  #    - calc  = use a value calculated based on Fy
  # Es = modulus of elasticity of the steel section
  #    - calc  = use a customary value
  # Added Elastic Stiffness
  #    - "-AddedElastic $EA $EI" for 2D sections
  #    - "-AddedElastic $EA $EIz $EIy $GJ" for 3D section

  # ########### Set Constants and Default Values ###########
  set pi  [expr 2*asin(1.0)]
  set steelMaterialType ProposedForBehavior
  set AddedElastic no
  set GJ calc

  # ########### Check Required Input ###########
  set D   [expr double($D)]
  set B   [expr double($B)]
  set t   [expr double($t)]
  set Fy  [expr double($Fy)]
  if { $Fu != "calc" } { set Fu  [expr double($Fu)] }
  if { $Es != "calc" } { set Es  [expr double($Es)] }

  set nf1 [expr int($nf1)]
  if { $nf1 <= 0 } {
    error "Error - recthssSection: the number of fibers (nf1) should be positive"
  }

  if { [string compare -nocase $nf2 "strong"] == 0 } {
    set bendingType 2dStrong
  } elseif { [string compare -nocase $nf2 "weak"] == 0 } {
    set bendingType 2dWeak
  } else {
    set bendingType 3d
    set nf2 [expr int($nf2)]
    if { $nf2 <= 0 } {
      error "Error - recthssSection: the number of fibers (nf2) should be positive"
    }
  }

  if { $D <= 0.0 } {
    error "Error - recthssSection: D should be input as a posititve value"
  }
  if { $B <= 0.0 } {
    error "Error - recthssSection: B should be input as a posititve value"
  }
  if { $t <= 0.0 } {
    error "Error - recthssSection: t should be input as a posititve value"
  }
  if { $t >= [expr 0.5*$D] || $t >= [expr 0.5*$B]} {
    error "Error - recthssSection: t is too large compared to D or B"
  }
  if { $Fy <= 0.0 } {
    error "Error - recthssSection: Steel yield strength should be input as a posititve values"
  }
  if { $Fu <= $Fy && $Fu != "calc" } {
    error "Error - recthssSection: Steel ultimate strength should be greater than yield strength or calc"
  }
  if { $Es <= 0.0 && $Es != "calc" } {
    error "Error - recthssSection: Steel elastic modulus should be input as a posititve values or calc"
  }


  # ########### Read Optional Input ###########
  for { set i 0 } { $i < [llength $args] } { incr i } {
    set param [lindex $args $i]
    if { $param == "-SteelMaterialType" } {
      set steelMaterialType [lindex $args [expr $i+1]]
      incr i 1
      continue
    }
    if { $param == "-GJ" } {
      set GJ [lindex $args [expr $i+1]]
      incr i 1
      continue
    }
    if { $param == "-AddedElastic" } {
      set AddedElastic yes
      if { $bendingType == "2dStrong" || $bendingType == "2dWeak" } {
        incr i
        set AddedElasticEA [lindex $args $i]
        incr i
        set AddedElasticEI [lindex $args $i]
      } elseif { $bendingType == "3d" } {
        incr i
        set AddedElasticEA [lindex $args $i]
        incr i
        set AddedElasticEIz [lindex $args $i] 
        incr i
        set AddedElasticEIy [lindex $args $i]
        incr i
        set AddedElasticGJ [lindex $args $i]       
      }
      continue
    }
    error "Error - recthssSection: unknown optional parameter: $param" 
  }



  # ########### Compute Fu and Es if necessary ###########
  if { $Fu == "calc" } {
    set Fu [defaultValue_Fu $Fy $units]
  }
  if { $Es == "calc" } {
    set Es [defaultValue_Es $units]
  }


  # ########### Compute Material Properties ###########
  set eu         [expr 120.0*$Fy/$Es]

  set epo_flat   0.0004    
  set epo_corner 0.0006
  set Fy_corner  [expr 1.09*$Fy]
  set Fu_corner  [expr 1.03*$Fu]
  if { $Fu_corner < $Fy_corner } { 
    set Fu_corner $Fy_corner 
  } 

  # ########### Compute GJ if necessary ###########
  if { $GJ == "calc" } { 
    set G  [expr $Es/(2*(1+0.3))]
    set J  [expr 2*$t*$D*$D*$B*$B/($D+$B)]
    set GJ [expr $G*$J]
  }

  # ########### Define Section by calling itself with secID = noSection ###########
  if { [string compare -nocase $secID "noSection"] != 0 } {
    section Fiber $secID -GJ $GJ {
      eval recthssSection noSection $startMatID $nf1 $nf2 $units $D $B $t $Fy $Fu $Es $args
    }
    return
  }


  # ########### Define Steel Materials ###########
  set stlFlatID     $startMatID
  set stlCornerID   [expr $startMatID+1]
  switch -exact -- $steelMaterialType {
    ProposedForBehavior_noLB {
        shenSteelMaterial $stlFlatID $Es $Fy $Fu $eu $units \
            -type CFT -initialPlasticStrain $epo_flat
        shenSteelMaterial $stlCornerID $Es $Fy_corner $Fu_corner $eu $units \
            -type CFT -initialPlasticStrain $epo_corner
    }
    AbdelRahman {
        hssSteelAbdelRahman $stlFlatID   $Fy $Es
        hssSteelAbdelRahman $stlCornerID $Fy $Es -corner $Fu $t $t
        # r (internal radius) = t (wall thickness)
    }
    AbdelRahman_LowHardening {
        hssSteelAbdelRahman $stlFlatID   $Fy $Es -HardeningRatio 0.001
        hssSteelAbdelRahman $stlCornerID $Fy $Es -corner $Fu $t $t -HardeningRatio 0.001
    }
    ElasticPP {
        uniaxialMaterial ElasticPP $stlFlatID   $Es [expr $Fy/$Es]
        uniaxialMaterial ElasticPP $stlCornerID $Es [expr $Fy/$Es]
    }
    Steel02 {
        set b   0.003
        set R0  20
        set cR1 0.925
        set cR2 0.15
        uniaxialMaterial Steel02 $stlFlatID   $Fy $Es $b $R0 $cR1 $cR2
        uniaxialMaterial Steel02 $stlCornerID $Fy $Es $b $R0 $cR1 $cR2
    }
    default {
        error "ERROR: recthssSection: unknown steel material type: $steelMaterialType"
    }
  }


  # ########### Define Section: 2d Strong ###########
  if { $bendingType == "2dStrong" } {

    # Steel Flat, Webs
    patchRect2d $stlFlatID [expr ceil(($D-4*$t)*($nf1/$D))] [expr 2*$t] [expr -$D/2+2*$t] [expr $D/2-2*$t]

    # Steel Flat, Top Flange
    patchRect2d $stlFlatID [expr ceil($t*($nf1/$D))] [expr $B-4*$t] [expr $D/2-$t] [expr $D/2]

    # Steel Flat, Botton Flange
    patchRect2d $stlFlatID [expr ceil($t*($nf1/$D))] [expr $B-4*$t] [expr -$D/2] [expr -$D/2+$t]

    # Steel Corners, Top Flange
    patchHalfCircTube2d $stlCornerID [expr ceil(2*$t*($nf1/$D))] [expr  $D/2-2*$t] top    [expr 4*$t] $t

    # Steel Corners, Bottom Flange
    patchHalfCircTube2d $stlCornerID [expr ceil(2*$t*($nf1/$D))] [expr -$D/2+2*$t] bottom [expr 4*$t] $t


  # ########### 2d Weak ###########
  } elseif { $bendingType == "2dWeak" } {

    # Steel Flat, Webs
    patchRect2d $stlFlatID [expr ceil(($B-4*$t)*($nf1/$B))] [expr 2*$t] [expr -$B/2+2*$t] [expr $B/2-2*$t]

    # Steel Flat, Top Flange
    patchRect2d $stlFlatID [expr ceil($t*($nf1/$B))] [expr $D-4*$t] [expr $B/2-$t] [expr $B/2]

    # Steel Flat, Botton Flange
    patchRect2d $stlFlatID [expr ceil($t*($nf1/$B))] [expr $D-4*$t] [expr -$B/2] [expr -$B/2+$t]

    # Steel Corners, Top Flange
    patchHalfCircTube2d $stlCornerID [expr ceil(2*$t*($nf1/$B))] [expr  $B/2-2*$t] top    [expr 4*$t] $t

    # Steel Corners, Bottom Flange
    patchHalfCircTube2d $stlCornerID [expr ceil(2*$t*($nf1/$B))] [expr -$B/2+2*$t] bottom [expr 4*$t] $t


  # ########### Define Section: 3d ###########
  } elseif { $bendingType == "3d" } {
    ##### STEEL #####
    ### Flat ###

    # Top (positive Y) Flange
    set yTop [expr $D/2]
    set yBottom [expr $D/2 - $t]
    set zLeft [expr -$B/2 + 2*$t]
    set zRight [expr $B/2 - 2*$t]
    set nfiy [expr round(ceil(($t)*($nf1/$D)))]
    set nfiz [expr round(ceil(($B-4*$t)*($nf2/$B)))]
    patch quad $stlFlatID $nfiz $nfiy $yTop $zLeft $yTop $zRight $yBottom $zRight $yBottom $zLeft

    # Bottom (negative Y) Flange
    set yTop [expr -$D/2 + $t]
    set yBottom [expr -$D/2]
    set zLeft [expr -$B/2 + 2*$t]
    set zRight [expr $B/2 - 2*$t]
    set nfiy [expr round(ceil(($t)*($nf1/$D)))]
    set nfiz [expr round(ceil(($B-4*$t)*($nf2/$B)))]
    patch quad $stlFlatID $nfiz $nfiy $yTop $zLeft $yTop $zRight $yBottom $zRight $yBottom $zLeft

    # Left (negative Y) Web
    set yTop [expr $D/2 - 2*$t]
    set yBottom [expr -$D/2 + 2*$t]
    set zLeft [expr -$B/2]
    set zRight [expr -$B/2 + $t]
    set nfiy [expr round(ceil(($D-4*$t)*($nf1/$D)))]
    set nfiz [expr round(ceil(($t)*($nf2/$B)))]
    patch quad $stlFlatID $nfiz $nfiy $yTop $zLeft $yTop $zRight $yBottom $zRight $yBottom $zLeft

    # Right (positive Y) Web
    set yTop [expr $D/2 - 2*$t]
    set yBottom [expr -$D/2 + 2*$t]
    set zLeft [expr $B/2 - $t]
    set zRight [expr $B/2]
    set nfiy [expr round(ceil(($D-4*$t)*($nf1/$D)))]
    set nfiz [expr round(ceil(($t)*($nf2/$B)))]
    patch quad $stlFlatID $nfiz $nfiy $yTop $zLeft $yTop $zRight $yBottom $zRight $yBottom $zLeft

    ### Corner ###
    if { [expr $D/double($nf1)] < [expr $B/double($nf2)] } { 
        set cornerFiberSize [expr $D/double($nf1)]
    } else {
        set cornerFiberSize [expr $B/double($nf2)]
    }
    
    # Top Right (positive Y, positive Z)
    set yCenter [expr $D/2 - 2*$t]
    set zCenter [expr $B/2 - 2*$t]
    set intRad [expr $t]
    set extRad [expr 2*$t]
    set startAng [expr 0]
    set endAng [expr 90]
    set nfic [expr round(ceil(($t*$pi)/$cornerFiberSize))]
    set nfir [expr round(ceil(($t)/$cornerFiberSize))]
    patch circ $stlCornerID $nfic $nfir $yCenter $zCenter $intRad $extRad $startAng $endAng

    # Top Left (positive Y, negative Z)
    set yCenter [expr $D/2 - 2*$t]
    set zCenter [expr -$B/2 + 2*$t]
    set intRad [expr $t]
    set extRad [expr 2*$t]
    set startAng [expr 270]
    set endAng [expr 360]
    set nfic [expr round(ceil(($t*$pi)/$cornerFiberSize))]
    set nfir [expr round(ceil(($t)/$cornerFiberSize))]
    patch circ $stlCornerID $nfic $nfir $yCenter $zCenter $intRad $extRad $startAng $endAng

    # Bottom Left (negative Y, negative Z)
    set yCenter [expr -$D/2 + 2*$t]
    set zCenter [expr -$B/2 + 2*$t]
    set intRad [expr $t]
    set extRad [expr 2*$t]
    set startAng [expr 180]
    set endAng [expr 270]
    set nfic [expr round(ceil(($t*$pi)/$cornerFiberSize))]
    set nfir [expr round(ceil(($t)/$cornerFiberSize))]
    patch circ $stlCornerID $nfic $nfir $yCenter $zCenter $intRad $extRad $startAng $endAng

    #  Bottom Right (negative Y, positive Z)
    set yCenter [expr -$D/2 + 2*$t]
    set zCenter [expr $B/2 - 2*$t]
    set intRad [expr $t]
    set extRad [expr 2*$t]
    set startAng [expr 90]
    set endAng [expr 180]
    set nfic [expr round(ceil(($t*$pi)/$cornerFiberSize))]
    set nfir [expr round(ceil(($t)/$cornerFiberSize))]
    patch circ $stlCornerID $nfic $nfir $yCenter $zCenter $intRad $extRad $startAng $endAng

  } else {
    error "Error - recthssSection: unknown bendingAxis"
  }

  # ########### Add elastic stiffness if necessary ###########
  if { $AddedElastic == "yes" } {
    set ElasticE 1.0;
    set matID [expr $startMatID+2]
    incr currentMatTag
    uniaxialMaterial Elastic $matID $ElasticE
    if { $bendingType == "2dStrong" || $bendingType == "2dWeak" } {
      twoFiberSection noSection $matID \
          [expr $AddedElasticEA/$ElasticE] \
          [expr $AddedElasticEI/$ElasticE]        
    } elseif { $bendingType == "3d" } {
      fourFiberSectionGJ noSection $matID \
          [expr $AddedElasticEA/$ElasticE] \
          [expr $AddedElasticEIy/$ElasticE] \
          [expr $AddedElasticEIz/$ElasticE] \
          $AddedElasticGJ    
    }
  }

}
