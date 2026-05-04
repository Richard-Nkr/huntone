# Huntone

Huntone est un prototype iOS SwiftUI : chaque jour, l'utilisateur recoit une couleur et capture 9 photos autour de cette couleur pour composer un frame carre partageable.

## MVP inclus

- couleur quotidienne personnalisee localement par installation ;
- home page avec feed mock des frames publies par d'autres utilisateurs ;
- photos et export frame au format portrait 4:5 ;
- auth iCloud, profils, amis, feed distant et stockage images via CloudKit ;
- grille 3x3 avec prise de photo camera ou import depuis Photos ;
- sauvegarde locale automatique des 9 images du jour ;
- export d'un frame carre partageable via la feuille de partage iOS.

## Ouvrir le projet

Ouvre `Huntone.xcodeproj` dans Xcode, choisis un simulateur iPhone ou un iPhone physique, puis lance la cible `Huntone`.

La camera necessite un iPhone physique. Sur simulateur, le picker bascule vers la bibliotheque photo.

## CloudKit

La couche utilisateur utilise CloudKit avec le container `iCloud.com.richaskip.huntone`.

Dans Xcode, configure une equipe Apple Developer, active iCloud + CloudKit pour la cible, puis cree ces record types dans CloudKit Dashboard :

- `UserProfile` : `userId`, `username`, `displayName`, `createdAt`, `updatedAt`
- `Friendship` : `requesterId`, `requesterName`, `addresseeId`, `addresseeName`, `status`, `createdAt`, `updatedAt`
- `FramePost` : `ownerId`, `ownerName`, `dateKey`, `colorName`, `colorHex`, `caption`, `createdAt`, `image0` a `image8`

Les images sont stockees comme `CKAsset` dans les champs `image0` a `image8`.
