proc OpenSeesComposite::roundhssSection { secID startMatID nf1 nf2 units D t Fy Fu Es args} {
  # ###################################################################
  # roundhssSection $secID $startMatID $nf1 $nf2 $units $D $t $Fy $Fu $Es
  # ###################################################################
  # tcl procedure for creating a round HSS steel fiber section
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
  # D  = outside diameter of the steel tube
  # t  = thickness of the steel tube
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
  set t   [expr double($t)]
  set Fy  [expr double($Fy)]
  if { $Fu != "calc" } { set Fu  [expr double($Fu)] }
  if { $Es != "calc" } { set Es  [expr double($Es)] }

  set nf1 [expr int($nf1)]
  if { $nf1 <= 0 } {
    error "Error - roundhssSection: the number of fibers (nf1) should be positive"
  }

  if { [string compare -nocase $nf2 "strong"] == 0 } {
    set bendingType 2dStrong
  } elseif { [string compare -nocase $nf2 "weak"] == 0 } {
    set bendingType 2dWeak
  } else {
    set bendingType 3d
    set nf2 [expr int($nf2)]
    if { $nf2 <= 0 } {
      error "Error - roundhssSection: the number of fibers (nf2) should be positive"
    }
  }

  if { $D <= 0.0 } {
    error "Error - roundhssSection: D should be input as a posititve value"
  }
  if { $t <= 0.0 } {
    error "Error - roundhssSection: t should be input as a posititve value"
  }
  if { $t >= [expr 0.5*$D] } {
    error "Error - roundhssSection: t is too large compared to D"
  }
  if { $Fy <= 0.0 } {
    error "Error - roundhssSection: Steel yield strength should be input as a posititve values"
  }
  if { $Fu <= $Fy && $Fu != "calc" } {
    error "Error - roundhssSection: Steel ultimate strength should be greater than yield strength or calc"
  }
  if { $Es <= 0.0 && $Es != "calc" } {
    error "Error - roundhssSection: Steel elastic modulus should be input as a posititve values or calc"
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
    error "Error - roundhssSection: unknown optional parameter: $param" 
  }



  # ########### Compute Fu and Es if necessary ###########
  if { $Fu == "calc" } {
    set Fu [defaultValue_Fu $Fy $units]
  }
  if { $Es == "calc" } {
    set Es [defaultValue_Es $units]
  }


  # ########### Set Additional Section Dimensions ###########
  set ro [expr 0.5*$D]
  set ri [expr $ro-$t]


  # ########### Compute Material Properties ###########
  set eu    [expr 120.0*$Fy/$Es]
  set epo   0.0006
  

  # ########### Compute GJ if necessary ###########
  if { $GJ == "calc" } { 
    set G  [expr $Es/(2*(1+0.3))]
    set J  [expr 0.5*$pi*(pow($ro,4)-pow($ri,4))]
    set GJ [expr $G*$J]
  }


  # ########### Define Section by calling itself with secID = noSection ###########
  if { [string compare -nocase $secID "noSection"] != 0 } {
    section Fiber $secID -GJ $GJ {
      eval roundhssSection noSection $startMatID $nf1 $nf2 $units $D $t $Fy $Fu $Es $args
    }
    return
  }


  # ########### Define Steel Materials ###########
  set stlID     $startMatID
  switch -exact -- $steelMaterialType {
    ProposedForBehavior_noLB {
      set Epst [expr $Es/100.0]
      shenSteelMaterial $stlID $Es $Fy $Fu $eu $units \
          -type coldFormed -initialPlasticStrain $epo \
          -initialPlasticModulus $Epst
    }
    AbdelRahman {
      hssSteelAbdelRahman $stlID $Fy $Es
    }
    ElasticPP {
      uniaxialMaterial ElasticPP $stlID $Es [expr $Fy/$Es]
    }
    Steel02 {
      set b   0.003
      set R0  20
      set cR1 0.925
      set cR2 0.15
      uniaxialMaterial Steel02 $stlID $Fy $Es $b $R0 $cR1 $cR2
    }
    default {
      error "ERROR: roundhssSection: unknown steel material type: $steelMaterialType"
    }
  }


  # ########### Define Section: 2d ###########
  if { $bendingType == "2dStrong" || $bendingType == "2dWeak" } {

    patchHalfCircTube2d $stlID [expr ceil($ro*($nf1/$D))] 0.0 top    $D $t
    patchHalfCircTube2d $stlID [expr ceil($ro*($nf1/$D))] 0.0 bottom $D $t

  # ########### Define Section: 3d ###########
  } elseif { $bendingType == "3d" } {
    
    if { $nf1 > $nf2 } {
        set nf $nf1
    } else {
        set nf $nf2
    }
    set nfc [expr round(ceil(($D*$pi)*($nf/$D)))]
    set nfr [expr round(ceil(($t)*($nf/$D)))]
    patch circ $stlID $nfc $nfr 0.0 0.0 $ri $ro 0.0 360.0    

  } else {
    error "Error - roundhssSection: unknown bendingAxis"
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
