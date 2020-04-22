proc CircularRC { secID startMatID nf1 nf2 units D fc Ec cover fy fu Es db Ab nBar fyt dbt Abt s transverse_reinf_type conc_material steel_material} {
    # ###################################################################  
    # CircularRC $secID $startMatID $nf1 $nf2 $units $D $fc $Ec $cover $fy $fu $Es $db $Ab $nBar $fyt $dbt $Abt $s $transverse_reinf_type $conc_material $steel_material
    # ###################################################################
    # tcl procedure for creating a circular reinforced concrete fiber section
    #
    # Required input arguments:
    # secID         = section ID number
    # startMatID    = starting ID number for the uniaxial materials that will be defined
    # nf1           = number of fibers along the primary bending axis (X-axis for 3d)
    # nf2           = number of fibers along the secondary bending axis
    #                 - X = creates a 2d section for X-axis bending
    #                 - Y = creates a 2d section for Y-axis bending
    # units         = unit system
    #                 - US = United States customary units (i.e., kips, inches, ksi)
    #                 - SI = International System of Units (i.e., N, mm, MPa)
    # D             = column diameter
    # fc            = concrete compressive strength
    # Ec            = modulus of elasticity of concrete
    # cover         = concrete cover measured from outside surface of concrete to edge of transverse reinforcing steel
    # fy            = longitudinal reinforcing steel yield stress
    # fu            = longitudinal reinforcing steel ultimate strength
    # Es            = modulus of elasticity of steel
    # db            = diameter of longitudinal reinforcing bar
    # Ab            = cross-sectional of longitudinal reinforcing bar
    # nBar          = number of longitudinal reinforcing bars
    # fyt           = transverse reinforcing steel yield stress (used for computing confinement only)
    # dbt           = diameter of transverse reinforcing bar
    # Abt           = cross-sectional of transverse reinforcing bar
    # s             = spacing of transverse reinfocring bar
    # transverse_reinf_type = type of lateral reinforcing
    #                 - Spiral
    #                 - Ties
    # conc_material = Concrete material type
    #                 - Elastic
    #                 - ElasticNoTension    
    #                 - Concrete04
    # steel_material = Steel material type
    #                 - Elastic
    #                 - ElasticPP    
    #                 - ElasticSmallStiffness
    # 

    # ########### Set Constants and Default Values ###########
    set pi  [expr 2*asin(1.0)]

    # ########### Check Required Input ###########
    set D    [expr double($D)]   
    set fc   [expr double($fc)]
    set fyt  [expr double($fyt)]
    set fu   [expr double($fu)]
    set Es   [expr double($Es)]

    set nf1  [expr int($nf1)]
    if { $nf1 <= 0 } {
        error "Error - CircularRC: the number of fibers (nf1) should be positive"
    }

    if { [string compare -nocase $nf2 "Z"] == 0 } {
        set bendingType 2dZ
    } elseif { [string compare -nocase $nf2 "Y"] == 0 } {
        set bendingType 2dY
    } else {
        set bendingType 3d
        set nf2 [expr int($nf2)]
        if { $nf2 <= 0 } {
            error "Error - CircularRC: the number of fibers (nf2) should be positive"
        }
    }

    if { $fc <= 0.0 } {
        error "Error - CircularRC: Concrete compressive strength should be input as a posititve value"
    }

    # ########### Define Section by calling itself with secID = noSection ###########
    if { [string compare -nocase $secID "noSection"] != 0 } {
        # Compute GJ
        set Gc  [expr $Ec/(2*(1+0.2))]
        set Jc  [expr 0.5*$pi*pow($D/2,4)]
        
        section Fiber $secID -GJ [expr $Gc*$Jc] {
            eval CircularRC noSection $startMatID $nf1 $nf2 $units $D $fc $Ec $cover $fy $fu $Es $db $Ab $nBar $fyt $dbt $Abt $s $transverse_reinf_type $conc_material $steel_material
        }
        return
    }
 
    # ########### Computed Properties ###########
    
    # Confined Concrete Strength (Mander et al. 1988)
    set ds      [expr $D - 2*$cover - $dbt]
    set Ac      [expr ($pi/4.0)*$ds*$ds]
    set As      [expr $nBar*$Ab]
    set rho_cc  [expr $As/$Ac]
    set sprime  [expr $s-$dbt]
    if { [string tolower $transverse_reinf_type] == "ties" } {
        set ke [expr (1-0.5*$sprime/$ds)*(1-0.5*$sprime/$ds)/(1.0-$rho_cc)]
    } elseif { [string tolower $transverse_reinf_type] == "spiral" } {
        set ke [expr (1-0.5*$sprime/$ds)/(1.0-$rho_cc)]
    } else {
        error "Error - CircularRC: unknown stirrup type: $transverse_reinf_type"
    }
    set rho_s   [expr 4.0*$Abt/($s*$ds)]
    set fl      [expr 0.5*$ke*$rho_s*$fyt]   
    set fcc     [expr $fc*(-1.254+2.254*sqrt(1+7.94*$fl/$fc)-2*$fl/$fc)]

    # Strain at Peak Stress
    switch -exact -- $units {
        US { set ec [expr pow($fc*6.89476,0.25)/1150.0] }
        SI { set ec [expr pow($fc,0.25)/1150.0] }
        default { error "ERROR: units not recognized" }
    }
    set ecc [expr $ec*(1+5*($fcc/$fc-1.0))]
    

    # ########### Define Concrete Materials ###########
    set coverConcID [expr $startMatID]
    set coreConcID  [expr $startMatID+1]
    switch -exact -- $conc_material {
        Concrete04 {
            set ecu 0.05
            uniaxialMaterial Concrete04 $coverConcID -$fc -$ec -$ecu $Ec
            uniaxialMaterial Concrete04 $coreConcID -$fcc -$ecc -$ecu $Ec
        }
        Elastic {
            uniaxialMaterial Elastic $coverConcID $Ec
            # uniaxialMaterial Elastic $coreConcID $Ec
            set coreConcID $coverConcID
        }
        ElasticNoTension {
            uniaxialMaterial ENT $coverConcID $Ec
            set coreConcID $coverConcID
        }
        default {
            error "ERROR: CircularRC: unknown concrete material type: $conc_material"
        }
    }


    # ########### Define Concrete Fibers: 2d ###########
    set r_gross [expr 0.5*$D]
    set r_core [expr 0.5*$D - $cover - 0.5*$dbt]
    if { $bendingType == "2dZ" || $bendingType == "2dY" } {

        # Define cover concrete
        patchHalfCircTube2d $coverConcID [expr ceil($r_gross*($nf1/$D))] 0.0 top    $D $cover
        patchHalfCircTube2d $coverConcID [expr ceil($r_gross*($nf1/$D))] 0.0 bottom $D $cover

        # Define core concrete
        patchHalfCircTube2d $coreConcID [expr ceil($r_core*($nf1/$D))] 0.0 top    [expr 2*$r_core] $r_core
        patchHalfCircTube2d $coreConcID [expr ceil($r_core*($nf1/$D))] 0.0 bottom [expr 2*$r_core] $r_core
   
    # ########### Define Concrete Fibers: 3d ###########
    } elseif { $bendingType == "3d" } {
        if { $nf1 > $nf2 } {
            set nf $nf1
        } else {
            set nf $nf2
        }

        # Define cover concrete
        set nfc [expr round(ceil(($D*$pi)*($nf/$D)))]
        set nfr [expr round(ceil(($cover)*($nf/$D)))]
        patch circ $coverConcID $nfc $nfr 0.0 0.0 $r_core $r_gross 0.0 360.0

        # Define core concrete
        # The concrete core is defined in four patchs to reduce number of fibers
        set nfc [expr round(ceil((2*$r_core*$pi)*($nf/$D)))]
        set nfr [expr round(ceil((2*$r_core*0.25)*($nf/$D)))]
        patch circ $coreConcID [expr round(ceil(0.25*$nfc))] $nfr 0.0 0.0 [expr 0.00*$r_core] [expr 0.25*$r_core] 0.0 360.0
        patch circ $coreConcID [expr round(ceil(0.50*$nfc))] $nfr 0.0 0.0 [expr 0.25*$r_core] [expr 0.50*$r_core] 0.0 360.0
        patch circ $coreConcID [expr round(ceil(0.75*$nfc))] $nfr 0.0 0.0 [expr 0.50*$r_core] [expr 0.75*$r_core] 0.0 360.0
        patch circ $coreConcID [expr round(ceil(1.00*$nfc))] $nfr 0.0 0.0 [expr 0.75*$r_core] [expr 1.00*$r_core] 0.0 360.0

    } else {
        error "Error - CircularRC: unknown bendingAxis"
    }


    # ########### Set Longitudinal Reinforcing Steel Materials ###########
    set reinfSteelID [expr $startMatID+2]
    switch -exact -- $steel_material {
        ElasticPP {
            uniaxialMaterial ElasticPP $reinfSteelID $Es [expr double($fy)/double($Es)]
        }
        ElasticSmallStiffness {
            uniaxialMaterial multiSurfaceKinematicHardening $reinfSteelID \
                -Direct $Es 0.0 $fy [expr double($Es)/1000.0]
        }
        Elastic {
            uniaxialMaterial Elastic $reinfSteelID $Es
        }
        default {
            error "Error - CircularRC: unknown reinforcing steel material type: $steel_material"
        }
    }

    # ########### Define Reinforcing Steel Fibers ###########
    set r_reinf [expr 0.5*$D - $cover - $dbt - 0.5*$db]
    if { $bendingType == "2dZ"} {
        for { set i 1 } { $i <= $nBar } { incr i } {
            set yLoc    [expr $r_reinf*sin(2*$pi/$nBar*$i)]
            set zLoc    0
            fiber $yLoc $zLoc -$Ab $coreConcID
            fiber $yLoc $zLoc  $Ab $reinfSteelID    
        }    
    } elseif { $bendingType == "2dY" } { 
        for { set i 1 } { $i <= $nBar } { incr i } {
            set yLoc    [expr $r_reinf*cos(2*$pi/$nBar*$i)]
            set zLoc    0
            fiber $yLoc $zLoc -$Ab $coreConcID
            fiber $yLoc $zLoc  $Ab $reinfSteelID    
        }  
    } elseif { $bendingType == "3d" } {
        for { set i 1 } { $i <= $nBar } { incr i } {
            set yLoc    [expr $r_reinf*sin(2*$pi/$nBar*$i)]
            set zLoc    [expr $r_reinf*cos(2*$pi/$nBar*$i)]
            fiber $yLoc $zLoc -$Ab $coreConcID
            fiber $yLoc $zLoc  $Ab $reinfSteelID
        }
    } else {
        error "Error - CircularRC: unknown bendingAxis"
    }
}