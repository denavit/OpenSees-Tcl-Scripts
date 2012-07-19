proc OpenSeesComposite::ccftSection { secID startMatID nf1 nf2 units D t Fy Fu Es fc args} {
    # ###################################################################
    # ccftSection $secID $startMatID $nf1 $nf2 $units $D $t $Fy $Fu $Es $fc
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
    # D  = outside depth of the steel tube
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

    # ########### Check Required Input ###########
    set D   [expr double($D)]
    set t   [expr double($t)]
    set Fy  [expr double($Fy)]
    if { $Fu != "calc" } { set Fu  [expr double($Fu)] }
    if { $Es != "calc" } { set Es  [expr double($Es)] }
    set fc  [expr double($fc)]

    set nf1 [expr int($nf1)]
    if { $nf1 <= 0 } {
        error "Error - ccftSection: the number of fibers (nf1) should be positive"
    }

    if { [string compare -nocase $nf2 "strong"] == 0 } {
        set bendingType 2dStrong
    } elseif { [string compare -nocase $nf2 "weak"] == 0 } {
        set bendingType 2dWeak
    } else {
        set bendingType 3d
        set nf2 [expr int($nf2)]
        if { $nf2 <= 0 } {
            error "Error - ccftSection: the number of fibers (nf2) should be positive"
        }
    }

    if { $D <= 0.0 } {
        error "Error - ccftSection: D should be input as a posititve value"
    }
    if { $t <= 0.0 } {
        error "Error - ccftSection: t should be input as a posititve value"
    }
    if { $t >= [expr 0.5*$D]} {
        error "Error - ccftSection: t is too large compared to D or B"
    }
    if { $Fy <= 0.0 } {
        error "Error - ccftSection: Steel yield strength should be input as a posititve value"
    }
    if { $Fu <= 0.0 && $Fu != "calc" } {
        error "Error - ccftSection: Steel ultimate strength should be input as a posititve values or calc"
    }
    if { $Es <= 0.0 && $Es != "calc" } {
        error "Error - ccftSection: Steel elastic modulus should be input as a posititve values or calc"
    }
    if { $fc <= 0.0 } {
        error "Error - ccftSection: Concrete compressive strength should be input as a posititve value"
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
        error "Error - ccftSection: unknown optional parameter: $param"
    }


  # ########### Compute Fu and Es if necessary ###########
  if { $Fu == "calc" } {
    set Fu [defaultValue_Fu $Fy $units]
  }
  if { $Es == "calc" } {
    set Es [defaultValue_Es $units]
  }


  # ########### Set Additional Section Dimensions ###########
  set rs [expr 0.5*$D]
  set rc [expr $rs-$t]

  # ########### Compute Material Properties ###########
  set alphaHoop             [expr 0.138 - 0.00174*$D/$t]
  if { $alphaHoop < 0.0 } { set alphaHoop 0.0 }
  set fl                    [expr 2*$alphaHoop*$Fy/($D/$t - 2)]
  set rn_post               [expr 0.4 + 0.016*($D/$t)*($fc/$Fy)]
  set R                     [expr ($D/$t)*($Fy/$Es)]
  set eu                    [expr 120.0*$Fy/$Es]
  set epo                   0.0006

  set localBucklingStrain   [expr 0.2139*pow($R,-1.413)*($Fy/$Es)]
  set Ksft                  [expr -$Es/30]
  set frs                   [expr 0.17/$R]
  if { $frs > 1.0 } { set frs 1.0 }


  # ########### Compute GJ if necessary ###########
  if { $GJ == "steelonly" } {
    set G  [expr $Es/(2*(1+0.3))]
    set J  [expr 0.5*$pi*(pow($rs,4)-pow($rc,4))]
    set GJ [expr $G*$J]
  }

  # ########### Define Section by calling itself with secID = noSection ###########
  if { [string is integer -strict $secID] } {
    section fiberSec $secID -GJ $GJ {
      eval ccftSection noSection $startMatID $nf1 $nf2 $units $D $t $Fy $Fu $Es $fc $args
    }
    return
  }

    # ########### Define Steel Materials ###########
    set stlID     $startMatID
    switch -exact -- $steelMaterialType {
        ProposedForBehavior {
            shenSteelMaterial $stlID $Es $Fy $Fu $eu $units \
                -type CFT -initialPlasticStrain $epo -biaxialStress $alphaHoop \
                -localBuckling -$localBucklingStrain $Ksft $frs Flb \
                -localBucklingDegradationEp    [expr 10.0*$R] 0.05 \
                -localBucklingDegradationKappa [expr 15.0*$R] 0.05
        }
        ProposedForBehavior_noLB {
            shenSteelMaterial $stlID $Es $Fy $Fu $eu $units \
                -type CFT -initialPlasticStrain $epo -biaxialStress $alphaHoop
        }
        AbdelRahman {
            hssSteelAbdelRahman $stlID $Fy $Es
        }
        ElasticPP {
            uniaxialMaterial ElasticPP $stlID $Es [expr $Fy/$Es]
        }
        Sakino {
            set epsyP [expr  1.08*$Fy/$Es]
            set epsyN [expr -0.89*$Fy/$Es]
            uniaxialMaterial ElasticPP $stlID $Es $epsyP $epsyN 0.0
        }
        default {
            error "ERROR: ccftSection: unknown steel material type: $steelMaterialType"
        }
    }


    # ########### Define Concrete Materials ###########
    set concID   [expr $startMatID+1]
    switch -exact -- $concMaterialType {
        ProposedForBehavior {
            changManderConcreteMaterial $concID $fc $units \
                -symmetric $fl -rn_post $rn_post
        }
        ProposedForBehavior_NoSoftening {
            changManderConcreteMaterial $concID $fc $units \
                -symmetric $fl -rn_post 0.0
        }
        ProposedForDesign {
            changManderConcreteMaterial $concID $fc $units \
                -symmetric $fl -r Popovics -tension none
        }
        ProposedForDesign_EI {
            changManderConcreteMaterial $concID $fc $units \
                -symmetric $fl -r Popovics
        }
        Sakino {
            ccftConcreteSakino $concID $fc $D $t $Fy $units
        }
        default {
            error "ERROR: ccftSection: unknown concrete material type: $concMaterialType"
        }
    }

    # ########### End function if just materials are to be defined ###########
    if { [string compare -nocase $secID "materialsOnly"] == 0 } {
      return
    }

    # ########### Define Fibers: 2d ###########
    if { $bendingType == "2dStrong" || $bendingType == "2dWeak" } {

        # Steel Tube
        patchHalfCircTube2d $stlID [expr ceil($rs*($nf1/$D))] 0.0 top    $D $t
        patchHalfCircTube2d $stlID [expr ceil($rs*($nf1/$D))] 0.0 bottom $D $t

        # Concrete Core
        patchHalfCircTube2d $concID [expr ceil($rc*($nf1/$D))] 0.0 top    [expr 2*$rc] $rc
        patchHalfCircTube2d $concID [expr ceil($rc*($nf1/$D))] 0.0 bottom [expr 2*$rc] $rc


    # ########### Define Fibers: 3d ###########
    } elseif { $bendingType == "3d" } {

        if { $nf1 > $nf2 } {
            set nf $nf1
        } else {
            set nf $nf2
        }

        # Steel Tube
        set nfc [expr round(ceil(($D*$pi)*($nf/$D)))]
        set nfr [expr round(ceil(($t)*($nf/$D)))]
        patch circ $stlID $nfc $nfr 0.0 0.0 $rc $rs 0.0 360.0

        # Concrete Core
        # The concrete core is defined in four patchs to reduce number of fibers
        set nfc [expr round(ceil((2*$rc*$pi)*($nf/$D)))]
        set nfr [expr round(ceil((2*$rc*0.25)*($nf/$D)))]
        patch circ $concID [expr round(ceil(0.25*$nfc))] $nfr 0.0 0.0 [expr 0.00*$rc] [expr 0.25*$rc] 0.0 360.0
        patch circ $concID [expr round(ceil(0.50*$nfc))] $nfr 0.0 0.0 [expr 0.25*$rc] [expr 0.50*$rc] 0.0 360.0
        patch circ $concID [expr round(ceil(0.75*$nfc))] $nfr 0.0 0.0 [expr 0.50*$rc] [expr 0.75*$rc] 0.0 360.0
        patch circ $concID [expr round(ceil(1.00*$nfc))] $nfr 0.0 0.0 [expr 0.75*$rc] [expr 1.00*$rc] 0.0 360.0


    } else {
        error "Error - ccftSection: unknown bendingAxis"
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
