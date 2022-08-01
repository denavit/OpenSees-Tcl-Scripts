proc OpenSeesComposite::wfSection { secID nf1 nf2 d tw bf tf args} {
  # ###################################################################
  # wfSection $secID $nf1 $nf2 $d $tw $bf $tf $material $args
  # ###################################################################
  # tcl procedure for creating a wide flange steel fiber section
  #
  # input parameters:
  # secID - section ID number
  #    - "noSection" defines just the fibers, used when the section has already been defined
  # nf1 = number of fibers along the primary bending axis (strong axis for 3d)
  # nf2 = number of fibers along the secondary bending axis
  #    - strong = creates a 2d section for strong axis bending
  #    - weak   = creates a 2d section for weak axis bending
  # d = nominal depth
  # tw = web thickness
  # bf = flange width
  # tf = flange thickness
  # material - define the material to be used
  #    - "-matTag $tag" = utilizes the unaixial materal defined with $tag
  #    - "-Elastic $matTag $Es" = utilizes an elastic material
  #    - "-ElasticPP $startMatTag $Es $Fy" = utilizes an elastically perfectly plastic (ElasticPP) material with residual stress pattern defined later
  #    - "-Steel01 $startMatTag $Es $Fy $b" = utilizes a Steel01 material with residual stress pattern defined later (using InitStressMaterial)
  #    - "-Steel02 $startMatTag $Es $Fy $b" = utilizes an Steel02 material with residual stress pattern defined later
  #    - "-Hardening $startMatTag $Es $Fy $b" = utilizes multiSurfaceKinematicHardening material with residual stress pattern defined later
  #    - "-ShenSteel $startMatTag $Es $Fy $Fu $eu $units" = utilizes an ShenSteel01 material with residual stress pattern defined later
  #    - "-ShenSteelDegrade $startMatTag $Es $Fy $Fu $eu $units" = utilizes an ShenSteel01 material with residual stress pattern defined later
  # resStress - define the residual stress patten
  #    - "-Lehigh $frc $nSectors" = a Lehigh pattern (Galambos and Ketter)
  # Added Elastic Stiffness
  #    - "-AddedElastic $EA $EI" for 2D sections
  #    - "-AddedElastic $EA $EIz $EIy $GJ" for 3D sections
  # Fillet
  #    - "-Fillet $k"


  # ########### Set Constants and Default Values ###########
  set currentMatTag          null
  set materialType           null
  set materialParams         null
  set residualStressType     null
  set residualStressParams   null
  set AddedElastic           no
  set GJ                     calc
  set Es                     0.0

  # ########### Check Required Input ###########
  set d    [expr double($d)]
  set tw   [expr double($tw)]
  set bf   [expr double($bf)]
  set tf   [expr double($tf)]
  set k    $tf

  set nf1 [expr int($nf1)]
  if { $nf1 <= 0 } {
    error "Error - wfSection: the number of fibers (nf1) should be positive"
  }

  if { [string compare -nocase $nf2 "strong"] == 0 } {
    set bendingType 2dStrong
  } elseif { [string compare -nocase $nf2 "weak"] == 0 } {
    set bendingType 2dWeak
  } else {
    set bendingType 3d
    set nf2 [expr int($nf2)]
    if { $nf2 <= 0 } {
      error "Error - wfSection: the number of fibers (nf2) should be positive"
    }
  }

  if { $d <= 0.0 || $tw <= 0.0 || $bf <= 0.0 || $tf <= 0.0 } {
    error "Error - wfSection: section dimensions should be input as posititve values"
  }

  # ########### Read Optional Input ###########
  for { set i 0 } { $i < [llength $args] } { incr i } {
    set param [lindex $args $i]
    if { $param == "-matTag" } {
      set materialType   "matTag"
      set currentMatTag  [lindex $args [expr $i+1]]
      incr i 1
      continue
    }
    if { $param == "-Elastic" } {
      set materialType   Elastic
      set currentMatTag  [lindex $args [expr $i+1]]
      set materialParams [lindex $args [expr $i+2]]
      incr i 2
      continue
    }
    if { $param == "-ElasticPP" } {
      set materialType   ElasticPP
      set currentMatTag  [lindex $args [expr $i+1]]
      set materialParams [lrange $args [expr $i+2] [expr $i+3]]
      set Es             [lindex $args [expr $i+2]]
      incr i 3
      continue
    }
    if { $param == "-ElasticSmallStiffness" } {
      set materialType   ElasticSmallStiffness
      set currentMatTag  [lindex $args [expr $i+1]]
      set materialParams [lrange $args [expr $i+2] [expr $i+3]]
      set Es             [lindex $args [expr $i+2]]
      incr i 3
      continue
    }
    if { $param == "-Hardening" } {
      set materialType   Hardening
      set currentMatTag  [lindex $args [expr $i+1]]
      set materialParams [lrange $args [expr $i+2] [expr $i+4]]
      set Es             [lindex $args [expr $i+2]]
      incr i 4
      continue
    }
    if { $param == "-Steel01" } {
      set materialType Steel01
      set currentMatTag  [lindex $args [expr $i+1]]
      set materialParams [lrange $args [expr $i+1] [expr $i+4]]
      set Es             [lindex $args [expr $i+2]]
      incr i 4
      continue
    }
    if { $param == "-Steel02" } {
      set materialType Steel02
      set currentMatTag  [lindex $args [expr $i+1]]
      set materialParams [lrange $args [expr $i+2] [expr $i+4]]
      set Es             [lindex $args [expr $i+2]]
      incr i 4
      continue
    }
    if { $param == "-ShenSteel" } {
      set materialType shenSteel
      set currentMatTag  [lindex $args [expr $i+1]]
      set materialParams [lrange $args [expr $i+2] [expr $i+6]]
      set Es             [lindex $args [expr $i+2]]
      incr i 6
      continue
    }
    if { $param == "-ShenSteelDegrade" } {
      set materialType shenSteelDegrade
      set currentMatTag  [lindex $args [expr $i+1]]
      set materialParams [lrange $args [expr $i+2] [expr $i+6]]
      set Es             [lindex $args [expr $i+2]]
      incr i 6
      continue
    }
    if { $param == "-Lehigh" } {
      set residualStressType   Lehigh
      set residualStressParams [lrange $args [expr $i+1] [expr $i+2]]
      incr i 2
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
    if { $param == "-Fillet" } {
      incr i
      set k [lindex $args $i]
      set k [expr double($k)]
      if { $k < $tf } {
        error "Error - wfSection: k should be larger than tf"
      }
      # other checks on k to make sure it isn't too large
      continue
    }
    if { $param == "-GJ" } {
      incr i
      set GJ [lindex $args $i]
      continue
    }
    error "Error - wfSection: unknown optional parameter: $param"
  }

  # ########### Set Additional Section Dimensions ###########
  set dw [expr $d - 2 * $tf]
  set d1 [expr $dw/2]
  set d2 [expr $d/2]
  set b1 [expr $tw/2]
  set b2 [expr $bf/2]

  # ########### Compute GJ if necessary ###########
  if { $GJ == "calc" } {
    if {$Es == 0.0} {
      if { $bendingType == "2dStrong" || $bendingType == "2dWeak" } {
        # GJ unnecessary
        set GJ 0.0
      } elseif { $bendingType == "3d" } {
        error "Error - wfSection: no E defined to calculate GJ"
      }
    } else {
      set G  [expr $Es/(2*(1+0.3))]
      set J  [expr (2*$bf*pow($tf,3) + pow($tw,2)*($d-2*$tf))/3.0]
      set GJ [expr $G*$J]
    }
  }

  # ########### Define Section by calling itself with secID = noSection ###########
  if { [string compare -nocase $secID "noSection"] != 0 } {
    section fiberSec $secID -GJ $GJ {
      eval wfSection noSection $nf1 $nf2 $d $tw $bf $tf $args
    }
    return
  }


  if { $materialType == "Elastic" } {
    set materialType matTag
    uniaxialMaterial Elastic $currentMatTag $materialParams
  }

  if { $materialType == "Steel01" } {
    set Es [expr double([lindex $materialParams 1])]
    set Fy [expr double([lindex $materialParams 2])]
    set b  [expr double([lindex $materialParams 3])]
    uniaxialMaterial Steel01 $currentMatTag $Fy $Es $b

    if { $residualStressType == "null" } {
      # If no residual stress, don't create a do-nothing InitStressMaterial
      # wrapper, instead use the base material we just created
      set materialType matTag
    } else {
      incr currentMatTag
    }
  }

  if { $materialType == "shenSteelDegrade" } {
    set Es    [expr double([lindex $materialParams 0])]
    set Fy    [expr double([lindex $materialParams 1])]
    set Fu    [expr double([lindex $materialParams 2])]

    set LpLi [expr 0.405 - 0.0033*($dw/$tw) - 0.0268*(0.5*$bf/$tf) + 0.184*($Fu/$Fy-1)]
    set elb  [expr -$Fy/$Es*(1+100*$LpLi/(1-$LpLi))]

    lappend materialParams $elb
  }

  if { $residualStressType == "null" && $materialType != "matTag" } {
    eval defineUniaxialMaterialWithResidualStress $currentMatTag 0.0 $materialType $materialParams
    set materialType matTag
  }

  if { $materialType == "matTag" } {
    set matTag $currentMatTag
    # ########### Define Fibers: 2d Strong ###########
    if { $bendingType == "2dStrong" } {
      patchRect2d $matTag [expr ceil(($nf1/$d)*$tf)]         $bf  $d1  $d2
      patchRect2d $matTag [expr ceil(($nf1/$d)*($d-2*$tf))]  $tw -$d1  $d1
      patchRect2d $matTag [expr ceil(($nf1/$d)*$tf)]         $bf -$d2 -$d1
      # Fillets
      if { $k > $tf } {
        set r [expr $k-$tf]
        set pi  [expr 2*asin(1.0)]
        set Afillet [expr (1-0.25*$pi)*$r*$r]
        set Yfillet [expr 2/(12-3*$pi)*$r]
        fiber [expr  $d1-$Yfillet] 0.0 [expr 2*$Afillet] $matTag
        fiber [expr -$d1+$Yfillet] 0.0 [expr 2*$Afillet] $matTag
      }
    # ########### Define Fibers: 2d Weak ###########
    } elseif { $bendingType == "2dWeak" } {
      patchRect2d $matTag [expr ceil(($nf1/$bf)*($bf-$tw)/2)]   [expr 2*$tf]  $b1  $b2
      patchRect2d $matTag [expr ceil(($nf1/$bf)*$tw)]           $d           -$b1  $b1
      patchRect2d $matTag [expr ceil(($nf1/$bf)*($bf-$tw)/2)]   [expr 2*$tf] -$b2 -$b1
      # Fillets
      if { $k > $tf } {
        set r [expr $k-$tf]
        set pi  [expr 2*asin(1.0)]
        set Afillet [expr (1-0.25*$pi)*$r*$r]
        set Yfillet [expr 2/(12-3*$pi)*$r]
        fiber [expr  $b1+$Yfillet] 0.0 [expr 2*$Afillet] $matTag
        fiber [expr -$b1-$Yfillet] 0.0 [expr 2*$Afillet] $matTag
      }
    # ########### Define Fibers: 3d ###########
    } elseif { $bendingType == "3d" } {
      patch quad $matTag [expr int(ceil(($nf1/$d)*$tf))]        [expr int(ceil(($nf2/$bf)*$bf))]  $d1 -$b2  $d2 -$b2  $d2  $b2  $d1  $b2
      patch quad $matTag [expr int(ceil(($nf1/$d)*($d-2*$tf)))] [expr int(ceil(($nf2/$bf)*$tw))] -$d1 -$b1  $d1 -$b1  $d1  $b1 -$d1  $b1
      patch quad $matTag [expr int(ceil(($nf1/$d)*$tf))]        [expr int(ceil(($nf2/$bf)*$bf))] -$d2 -$b2 -$d1 -$b2 -$d1  $b2 -$d2  $b2
      # Fillets
      if { $k > $tf } {
        set r [expr $k-$tf]
        set pi  [expr 2*asin(1.0)]
        set Afillet [expr (1-0.25*$pi)*$r*$r]
        set Yfillet [expr 2/(12-3*$pi)*$r]
        fiber [expr  $d1-($r-$Yfillet)] [expr  $b1+($r-$Yfillet)] $Afillet $matTag
        fiber [expr -$d1+($r-$Yfillet)] [expr  $b1+($r-$Yfillet)] $Afillet $matTag
        fiber [expr  $d1-($r-$Yfillet)] [expr -$b1-($r-$Yfillet)] $Afillet $matTag
        fiber [expr -$d1+($r-$Yfillet)] [expr -$b1-($r-$Yfillet)] $Afillet $matTag
      }
    } else {
      error "Error - wfSection: unknown bendingAxis"
    }

  } else {
    # ########### Define Fibers: Lehigh Residual Stress Pattern ###########
    if { $residualStressType == "Lehigh" } {
      set frc          [lindex $residualStressParams 0]
      set numSectors   [lindex $residualStressParams 1]

      if { $frc > 0 } {
        error "Error - wfSection: the compressive residual stress (frc) should be negative"
      }

      if { $k > $tf } {
        set r [expr $k-$tf]
        set pi  [expr 2*asin(1.0)]
        set Afillet [expr (1-0.25*$pi)*$r*$r]
        set frt [expr -1*$frc*($bf*$tf)/($bf*$tf+$tw*$dw+4*$Afillet)]
      } else {
        set frt [expr -1*$frc*($bf*$tf)/($bf*$tf+$tw*$dw)]
      }

      set LehighStartMatTag $currentMatTag

      for { set i 1 } { $i <= $numSectors } { incr i } {
        set matID    $currentMatTag
        incr currentMatTag
        set x        [expr (double($i)-0.5)/double($numSectors)]
        set fr       [expr $frc + $x*($frt-$frc)]
        # Define Materials
        eval defineUniaxialMaterialWithResidualStress $matID $fr $materialType $materialParams
      }
      set matID $currentMatTag
      incr currentMatTag
      eval defineUniaxialMaterialWithResidualStress $matID $frt $materialType $materialParams

      # ########### Define Fibers: 2d Strong ###########
      if { $bendingType == "2dStrong" } {
        # Flanges
        set bf1 [expr (1.0/double($numSectors))*$bf]
        for { set i 1 } { $i <= $numSectors } { incr i } {
          set matID [expr $LehighStartMatTag+($i-1)]
          patchRect2d $matID [expr int(ceil(($nf1/$d)*$tf))]  $bf1  $d1  $d2
          patchRect2d $matID [expr int(ceil(($nf1/$d)*$tf))]  $bf1 -$d2 -$d1
        }
        # Web
        set matID [expr $LehighStartMatTag+$numSectors]
        patchRect2d $matID [expr int(ceil(($nf1/$d)*($d-2*$tf)))]  $tw -$d1  $d1
        # Fillets
        if { $k > $tf } {
          set r [expr $k-$tf]
          set pi  [expr 2*asin(1.0)]
          set Afillet [expr (1-0.25*$pi)*$r*$r]
          set Yfillet [expr 2/(12-3*$pi)*$r]
          fiber [expr  $d1-$Yfillet] 0.0 [expr 2*$Afillet] $matID
          fiber [expr -$d1+$Yfillet] 0.0 [expr 2*$Afillet] $matID
        }

      # ########### Define Fibers: 2d Weak ###########
      } elseif { $bendingType == "2dWeak" } {
        # Flanges
        set b21 [expr (1.0/double($numSectors))*$b2]
        for { set i 1 } { $i <= $numSectors } { incr i } {
          set bft [expr $b2 - double($i-1)*$b21]
          set matID [expr $LehighStartMatTag+($i-1)]
          patchRect2d $matID [expr int(ceil(($nf1/$bf)*$b21))] [expr 2*$tf]  [expr $bft-$b21] $bft
          patchRect2d $matID [expr int(ceil(($nf1/$bf)*$b21))] [expr 2*$tf]  -$bft [expr -$bft+$b21]
        }
        # Web
        set matID [expr $LehighStartMatTag+$numSectors]
        patchRect2d $matID [expr int(ceil(($nf1/$bf)*($tw)))] $dw -$b1  $b1
        # Fillets
        if { $k > $tf } {
          set r [expr $k-$tf]
          set pi  [expr 2*asin(1.0)]
          set Afillet [expr (1-0.25*$pi)*$r*$r]
          set Yfillet [expr 2/(12-3*$pi)*$r]
          fiber [expr  $b1+$Yfillet] 0.0 [expr 2*$Afillet] $matID
          fiber [expr -$b1-$Yfillet] 0.0 [expr 2*$Afillet] $matID
        }

      # ########### Define Fibers: 3d ###########
      } elseif { $bendingType == "3d" } {
        # Flanges
        set bf1 [expr (1.0/double($numSectors))*($bf/2.0)]
        for { set i 1 } { $i <= $numSectors } { incr i } {
          set matID [expr $LehighStartMatTag+($i-1)]
          set b2i   [expr $b2-$bf1*($i-1)]
          set b1i   [expr $b2i-$bf1]
          if { $b1i < 0 } { set b1i 0.0 }
          patch quad $matID [expr int(ceil(($nf1/$d)*$tf))] [expr int(ceil(($nf2/$bf)*$bf1))]  $d1 -$b2i  $d2 -$b2i  $d2 -$b1i  $d1 -$b1i
          patch quad $matID [expr int(ceil(($nf1/$d)*$tf))] [expr int(ceil(($nf2/$bf)*$bf1))]  $d1  $b1i  $d2  $b1i  $d2  $b2i  $d1  $b2i
          patch quad $matID [expr int(ceil(($nf1/$d)*$tf))] [expr int(ceil(($nf2/$bf)*$bf1))] -$d2 -$b2i -$d1 -$b2i -$d1 -$b1i -$d2 -$b1i
          patch quad $matID [expr int(ceil(($nf1/$d)*$tf))] [expr int(ceil(($nf2/$bf)*$bf1))] -$d2  $b1i -$d1  $b1i -$d1  $b2i -$d2  $b2i
        }
        # Web
        set matID [expr $LehighStartMatTag+$numSectors]
        patch quad $matID [expr int(ceil(($nf1/$d)*$dw))] [expr int(ceil(($nf2/$bf)*$tw))] -$d1 -$b1 $d1 -$b1 $d1 $b1 -$d1 $b1
        # Fillets
        if { $k > $tf } {
          set r [expr $k-$tf]
          set pi  [expr 2*asin(1.0)]
          set Afillet [expr (1-0.25*$pi)*$r*$r]
          set Yfillet [expr 2/(12-3*$pi)*$r]
          fiber [expr  $d1-($r-$Yfillet)] [expr  $b1+($r-$Yfillet)] $Afillet $matID
          fiber [expr -$d1+($r-$Yfillet)] [expr  $b1+($r-$Yfillet)] $Afillet $matID
          fiber [expr  $d1-($r-$Yfillet)] [expr -$b1-($r-$Yfillet)] $Afillet $matID
          fiber [expr -$d1+($r-$Yfillet)] [expr -$b1-($r-$Yfillet)] $Afillet $matID
        }

      } else {
        error "Error - wfSection: unknown bendingAxis"
      }
    } else {
      error "ERROR: residualStressType not recgonized: $residualStressType"
    }
  }

  # ########### Add elastic stiffness if necessary ###########
  if { $AddedElastic == "yes" } {
    set ElasticE 1.0;
    set matID $currentMatTag
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



proc OpenSeesComposite::defineUniaxialMaterialWithResidualStress {matID fr materialType args} {
  # defineUniaxialMaterialWithResidualStress $matID $fr $materialType $args
  #
  # matID - material ID number
  # fr - residual stress
  # materialType - type of material to define
  # args - arguments used to define the uniaxial material

  switch -exact -- $materialType {
    ElasticPP {
      set Es [expr double([lindex $args 0])]
      set Fy [expr double([lindex $args 1])]
      set epsyP [expr  $Fy/$Es]
      set epsyN [expr -$Fy/$Es]
      set epsy0 [expr -$fr/$Es]
      uniaxialMaterial ElasticPP $matID $Es $epsyP $epsyN $epsy0
    }
    ElasticSmallStiffness {
      set Es [expr double([lindex $args 0])]
      set Fy [expr double([lindex $args 1])]
      uniaxialMaterial multiSurfaceKinematicHardening $matID -initialStress $fr -Direct $Es 0.0 $Fy [expr $Es/1000.0]
    }
    Hardening {
      set Es [expr double([lindex $args 0])]
      set Fy [expr double([lindex $args 1])]
      set b  [expr double([lindex $args 2])]
      uniaxialMaterial multiSurfaceKinematicHardening $matID -initialStress $fr -Direct $Es 0.0 $Fy [expr $b*$Es]
    }
    Steel01 {
      set baseMatID [lindex $args 0]
      uniaxialMaterial InitStressMaterial $matID $baseMatID $fr
    }
    Steel02 {
      set Es [expr double([lindex $args 0])]
      set Fy [expr double([lindex $args 1])]
      set b  [expr double([lindex $args 2])]
      uniaxialMaterial Steel02 $matID $Fy $Es $b 20.0 0.925 0.15 0.0 1.0 0.0 1.0 $fr
    }
    shenSteel {
      set Es    [lindex $args 0]
      set Fy    [lindex $args 1]
      set Fu    [lindex $args 2]
      set eu    [lindex $args 3]
      set units [lindex $args 4]
      shenSteelMaterial $matID $Es $Fy $Fu $eu $units \
          -type hotRolled -initialStress $fr
    }
    shenSteelDegrade {
      set Es    [lindex $args 0]
      set Fy    [lindex $args 1]
      set Fu    [lindex $args 2]
      set eu    [lindex $args 3]
      set units [lindex $args 4]
      set elb   [lindex $args 5]
      set Ksft  [expr -$Es/200.0]
      set frs   [expr 0.2]
      shenSteelMaterial $matID $Es $Fy $Fu $eu $units \
          -type hotRolled -initialStress $fr \
          -localBuckling [expr $elb+$fr/$Es] $Ksft $frs Fy \
          -localBucklingDegradationEp 2.0 0.05 \
          -localBucklingDegradationKappa 2.0 0.05

    }
    default {
      error "ERROR: defineUniaxialMaterialWithResidualStress - materialType not recgonized"
    }
  }
}
