# Register the package
package provide OpenSeesComposite 0.1

# Create the namespace
namespace eval OpenSeesComposite {
    # Export Material Commands
    namespace export \
        ccftConcreteSakino rcftSteelSakino rcftConcreteSakino \
        hssSteelAbdelRahman \
        shenSteelMaterial changManderConcreteMaterial \
        simplePanelZoneMaterial

    # Export Section Commands
    namespace export \
        roundhssSection recthssSection wfSection \
        ccftSection rcftSection srcSection \
        fourFiberSectionGJ twoFiberSection \
        RectangularRC CircularRC

    # Export Miscellaneous Commands
    namespace export \
        wShapeLookup eigenRecorder updateRayleighDamping printNodeCoordinates \
        printModelGeometry
}