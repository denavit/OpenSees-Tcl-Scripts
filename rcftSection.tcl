proc OpenSeesComposite::rcftSection { secID startMatID nf1 nf2 units D B t Fy Fu Es fc args} {
    # ###################################################################
    # rcftSection $secID $startMatID $nf1 $nf2 $units $D $B $t $Fy $Fu $Es $fc
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
    # D  = depth of the steel tube
    # B = width of the steel tube
    # t = thickness of the steel tube
    # Fy = yield strength of the steel section
    # Fu = ultimate strength of the steel section
    #    - calc  = use a value calculated based on Fy
    # Es = modulus of elasticity of the steel section
    #    - calc  = use a customary value
    # fc = concrete compressive strength
    # Added Elastic Stiffness
    #    - "-AddedElastic $EA $EI" for 2D sections
    #    - "-AddedElastic $EA $EIz $EIy $GJ" for 3D sections

    # ########### Set Constants and Default Values ###########
    set pi  [expr 2*asin(1.0)]
    set concMaterialType  ProposedForBehavior
    set steelMaterialType ProposedForBehavior
    set AddedElastic no
    set GJ steelonly
    set AbdelRahmanResidualStressParameter 0.75
    set AbdelRahmanHardeningRatio 0.005

    # ########### Check Required Input ###########
    set D   [expr double($D)]
    set B   [expr double($B)]
    set t   [expr double($t)]
    set Fy  [expr double($Fy)]
    if { $Fu != "calc" } { set Fu  [expr double($Fu)] }
    if { $Es != "calc" } { set Es  [expr double($Es)] }
    set fc  [expr double($fc)]

    set nf1 [expr int($nf1)]
    if { $nf1 <= 0 } {
        error "Error - rcftSection: the number of fibers (nf1) should be positive"
    }

    if { [string compare -nocase $nf2 "strong"] == 0 } {
        set bendingType 2dStrong
    } elseif { [string compare -nocase $nf2 "weak"] == 0 } {
        set bendingType 2dWeak
    } else {
        set bendingType 3d
        set nf2 [expr int($nf2)]
        if { $nf2 <= 0 } {
            error "Error - rcftSection: the number of fibers (nf2) should be positive"
        }
    }

    if { $D <= 0.0 } {
        error "Error - rcftSection: D should be input as a posititve value"
    }
    if { $B <= 0.0 } {
        error "Error - rcftSection: B should be input as a posititve value"
    }
    if { $t <= 0.0 } {
        error "Error - rcftSection: t should be input as a posititve value"
    }
    if { $t >= [expr 0.5*$D] || $t >= [expr 0.5*$B]} {
        error "Error - rcftSection: t is too large compared to D or B"
    }
    if { $Fy <= 0.0 } {
        error "Error - rcftSection: Steel yield strength should be input as a posititve value"
    }
    if { $Fu <= 0.0 && $Fu != "calc" } {
        error "Error - rcftSection: Steel ultimate strength should be input as a posititve values or calc"
    }
    if { $Es <= 0.0 && $Es != "calc" } {
        error "Error - rcftSection: Steel elastic modulus should be input as a posititve values or calc"
    }
    if { $fc <= 0.0 } {
        error "Error - rcftSection: Concrete compressive strength should be input as a posititve value"
    }


    # ########### Read Optional Input ###########
    for { set i 0 } { $i < [llength $args] } { incr i } {
        set param [lindex $args $i]
        if { $param == "-ConcreteMaterialType" } {
            set concMaterialType [lindex $args [expr $i+1]]
            incr i 1
            continue
        }
        if { $param == "-SteelMaterialType" } {
            set steelMaterialType [lindex $args [expr $i+1]]
            incr i 1
            if { $steelMaterialType == "ModifiedAbdelRahman" } {
                set AbdelRahmanResidualStressParameter [lindex $args [expr $i+1]]
                set AbdelRahmanHardeningRatio [lindex $args [expr $i+2]]
                incr i 2
            }
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
        error "Error - rcftSection: unknown optional parameter: $param"
    }


  # ########### Compute Fu and Es if necessary ###########
  if { $Fu == "calc" } {
    set Fu [defaultValue_Fu $Fy $units]
  }
  if { $Es == "calc" } {
    set Es [defaultValue_Es $units]
  }
  

  # ########### Compute Material Properties ###########
  if { $D > $B } {
    set H $D
  } else {
    set H $B
  }
  
  set rn_post               [expr 1.7*($H/$t)*sqrt($Fy/$Es)*($fc/$Fy)]
  set R1                    [expr ($H/$t)*sqrt($Fy/$Es)]
  set R2                    [expr ($H/$t)*($Fy/$Es)]
  set localBucklingStrain   [expr -3.14*pow($R1,-1.48)*($Fy/$Es)]
  set eu                    [expr 120.0*$Fy/$Es]
  
  set Ksft                  [expr 3.22*(0.08-$R2)*$Es]
  if { $Ksft > [expr -$Es/30.0] } { set Ksft [expr -$Es/30.0]}
  set frs                   [expr 1.0+7.31*(0.08-$R2)]
  if { $frs > 1.0 } { set frs 1.0 }

  set epo_flat              0.0004
  set epo_corner            0.0006
  set Fy_corner             [expr 1.09*$Fy]
  set Fu_corner             [expr 1.03*$Fu]
  if { $Fu_corner < $Fy_corner } {
    set Fu_corner $Fy_corner
  }

  # ########### Compute GJ if necessary ###########
  if { $GJ == "steelonly" } {
    set G  [expr $Es/(2*(1+0.3))]
    set J  [expr 2*$t*$D*$D*$B*$B/($D+$B)]
    set GJ [expr $G*$J]
  }

  # ########### Define Section by calling itself with secID = noSection ###########
  if { [string is integer -strict $secID] } {
    section Fiber $secID -GJ $GJ {
      eval rcftSection noSection $startMatID $nf1 $nf2 $units $D $B $t $Fy $Fu $Es $fc $args
    }
    return
  }

    # ########### Define Steel Materials ###########
    set stlFlatID     $startMatID
    set stlCornerID   [expr $startMatID+1]
    switch -exact -- $steelMaterialType {
        ProposedForBehavior {
            shenSteelMaterial $stlFlatID $Es $Fy $Fu $eu $units \
                -type CFT -initialPlasticStrain $epo_flat  \
                -localBuckling $localBucklingStrain $Ksft $frs Fy \
                -localBucklingDegradationEp    [expr 20.0*$R2] 0.05 \
                -localBucklingDegradationKappa [expr 30.0*$R2] 0.05
            shenSteelMaterial $stlCornerID $Es $Fy_corner $Fu_corner $eu $units \
                -type CFT -initialPlasticStrain $epo_corner  \
                -localBuckling $localBucklingStrain $Ksft $frs Fy \
                -localBucklingDegradationEp    [expr 20.0*$R2] 0.05 \
                -localBucklingDegradationKappa [expr 30.0*$R2] 0.05
        }
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
        ModifiedAbdelRahman {
            hssSteelAbdelRahman $stlFlatID   $Fy $Es -ResidualStressParameter $AbdelRahmanResidualStressParameter -HardeningRatio $AbdelRahmanHardeningRatio
            hssSteelAbdelRahman $stlCornerID $Fy $Es -corner $Fu $t $t -ResidualStressParameter $AbdelRahmanResidualStressParameter -HardeningRatio $AbdelRahmanHardeningRatio
            # r (internal radius) = t (wall thickness)
        }
        Elastic {
            uniaxialMaterial Elastic $stlFlatID   $Es
            uniaxialMaterial Elastic $stlCornerID $Es
        }
        ElasticPP {
            uniaxialMaterial ElasticPP $stlFlatID   $Es [expr $Fy/$Es]
            uniaxialMaterial ElasticPP $stlCornerID $Es [expr $Fy/$Es]
        }
        Sakino {
            rcftSteelSakino $stlFlatID   $Fy $Es $H $t
            rcftSteelSakino $stlCornerID $Fy $Es $H $t
        }
        default {
            error "ERROR: rcftSection: unknown steel material type: $steelMaterialType"
        }
    }


    # ########### Define Concrete Materials ###########
    set concID   [expr $startMatID+2]
    switch -exact -- $concMaterialType {
        ProposedForBehavior {
            changManderConcreteMaterial $concID $fc $units \
                -rn_post $rn_post
        }
        ProposedForDesign {
            changManderConcreteMaterial $concID $fc $units \
                -r Popovics -tension none
        }
        ProposedForDesign_EI {
            changManderConcreteMaterial $concID $fc $units \
                -r Popovics -tension Popovics
        }
        Elastic {
            switch -exact -- $units {
                US { set Ec [expr 1802.5*sqrt($fc)] }
                SI { set Ec [expr 4733.0*sqrt($fc)] }
                default { error "ERROR: units not recgonized" }
            }
            uniaxialMaterial Elastic $concID $Ec
        }
        ElasticNoTension {
            switch -exact -- $units {
                US { set Ec [expr 1802.5*sqrt($fc)] }
                SI { set Ec [expr 4733.0*sqrt($fc)] }
                default { error "ERROR: units not recgonized" }
            }
            uniaxialMaterial ENT $concID $Ec
        }
        Sakino {
            rcftConcreteSakino $concID $fc $H $t $Fy $units
        }
        default {
            error "ERROR: rcftSection: unknown concrete material type: $concMaterialType"
        }
    }


    # ########### End function if just materials are to be defined ###########
    if { [string compare -nocase $secID "materialsOnly"] == 0 } {
      return
    }

    # ########### Define Fibers: 2d Strong ###########
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

        # Concrete, Near Top Flange
        patchRect2d $concID [expr ceil($t*($nf1/$D))] [expr $B-4*$t] [expr $D/2-2*$t] [expr $D/2-$t]

        # Concrete, Near Bottom Flange
        patchRect2d $concID [expr ceil($t*($nf1/$D))] [expr $B-4*$t] [expr -$D/2+$t] [expr -$D/2+2*$t]

        # Concrete, Corners Near Top Flange
        patchHalfCircTube2d $concID [expr ceil($t*($nf1/$D))] [expr  $D/2-2*$t] top     [expr 2*$t] $t

        # Concrete, Corners Near Bottom Flange
        patchHalfCircTube2d $concID [expr ceil($t*($nf1/$D))] [expr  -$D/2+2*$t] bottom [expr 2*$t] $t

        # Concrete, Middle
        patchRect2d $concID [expr ceil(($D-4*$t)*($nf1/$D))] [expr $B-2*$t] [expr -$D/2+2*$t] [expr $D/2-2*$t]

    # ########### Define Fibers: 2d Weak ###########
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

        # Concrete, Near Top Flange
        patchRect2d $concID [expr ceil($t*($nf1/$B))] [expr $D-4*$t] [expr $B/2-2*$t] [expr $B/2-$t]

        # Concrete, Near Bottom Flange
        patchRect2d $concID [expr ceil($t*($nf1/$B))] [expr $D-4*$t] [expr -$B/2+$t] [expr -$B/2+2*$t]

        # Concrete, Corners Near Top Flange
        patchHalfCircTube2d $concID [expr ceil($t*($nf1/$B))] [expr  $B/2-2*$t] top     [expr 2*$t] $t

        # Concrete, Corners Near Bottom Flange
        patchHalfCircTube2d $concID [expr ceil($t*($nf1/$B))] [expr  -$B/2+2*$t] bottom [expr 2*$t] $t

        # Concrete, Middle
        patchRect2d $concID [expr ceil(($B-4*$t)*($nf1/$B))] [expr $D-2*$t] [expr -$B/2+2*$t] [expr $B/2-2*$t]

    # ########### Define Fibers: 3d ###########
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


        ##### CONCRETE #####
        ### Corners ###

        # Top Right (positive Y, positive Z)
        set yCenter [expr $D/2 - 2*$t]
        set zCenter [expr $B/2 - 2*$t]
        set intRad [expr 0]
        set extRad [expr $t]
        set startAng [expr 0]
        set endAng [expr 90]
        set nfic [expr round(ceil((0.5*$t*$pi)/$cornerFiberSize))]
        set nfir [expr round(ceil(($t)/$cornerFiberSize))]
        patch circ $concID $nfic $nfir $yCenter $zCenter $intRad $extRad $startAng $endAng

        # Top Left (positive Y, negative Z)
        set yCenter [expr $D/2 - 2*$t]
        set zCenter [expr -$B/2 + 2*$t]
        set intRad [expr 0]
        set extRad [expr $t]
        set startAng [expr 270]
        set endAng [expr 360]
        set nfic [expr round(ceil((0.5*$t*$pi)/$cornerFiberSize))]
        set nfir [expr round(ceil(($t)/$cornerFiberSize))]
        patch circ $concID $nfic $nfir $yCenter $zCenter $intRad $extRad $startAng $endAng

        # Bottom Left (negative Y, negative Z)
        set yCenter [expr -$D/2 + 2*$t]
        set zCenter [expr -$B/2 + 2*$t]
        set intRad [expr 0]
        set extRad [expr $t]
        set startAng [expr 180]
        set endAng [expr 270]
        set nfic [expr round(ceil((0.5*$t*$pi)/$cornerFiberSize))]
        set nfir [expr round(ceil(($t)/$cornerFiberSize))]
        patch circ $concID $nfic $nfir $yCenter $zCenter $intRad $extRad $startAng $endAng

        #  Bottom Right (negative Y, positive Z)
        set yCenter [expr -$D/2 + 2*$t]
        set zCenter [expr $B/2 - 2*$t]
        set intRad [expr 0]
        set extRad [expr $t]
        set startAng [expr 90]
        set endAng [expr 180]
        set nfic [expr round(ceil((0.5*$t*$pi)/$cornerFiberSize))]
        set nfir [expr round(ceil(($t)/$cornerFiberSize))]
        patch circ $concID $nfic $nfir $yCenter $zCenter $intRad $extRad $startAng $endAng

        ### Along Steel Flanges in Corner Radius ###

        # Top (positive Y) Flange
        set yTop [expr $D/2 - $t]
        set yBottom [expr $D/2 - 2*$t]
        set zLeft [expr -$B/2 + 2*$t]
        set zRight [expr $B/2 - 2*$t]
        set nfiy [expr round(ceil(($t)*($nf1/$D)))]
        set nfiz [expr round(ceil(($B-4*$t)*($nf2/$B)))]
        patch quad $concID $nfiz $nfiy $yTop $zLeft $yTop $zRight $yBottom $zRight $yBottom $zLeft

        # Bottom (negative Y) Flange
        set yTop [expr -$D/2 + 2*$t]
        set yBottom [expr -$D/2 + $t]
        set zLeft [expr -$B/2 + 2*$t]
        set zRight [expr $B/2 - 2*$t]
        set nfiy [expr round(ceil(($t)*($nf1/$D)))]
        set nfiz [expr round(ceil(($B-4*$t)*($nf2/$B)))]
        patch quad $concID $nfiz $nfiy $yTop $zLeft $yTop $zRight $yBottom $zRight $yBottom $zLeft

        ### Core ###

        set yTop [expr $D/2 - 2*$t]
        set yBottom [expr -$D/2 + 2*$t]
        set zLeft [expr -$B/2 + $t]
        set zRight [expr $B/2 - $t]
        set nfiy [expr round(ceil(($D-4*$t)*($nf1/$D)))]
        set nfiz [expr round(ceil(($B-2*$t)*($nf2/$B)))]
        patch quad $concID $nfiz $nfiy $yTop $zLeft $yTop $zRight $yBottom $zRight $yBottom $zLeft



    } else {
        error "Error - rcftSection: unknown bendingAxis"
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
