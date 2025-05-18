// import 'package:nirfx/models/version_description.dart';

class VersionData {
  static const String versionNumber = '0.1';
  static const int buildNumber = 1;
  static get appVersionString =>
      versionNumber + (buildNumber > 1 ? 'b$buildNumber' : '');

  // static bool displayInDebugAnyway = true;

  // static VersionFeature generalBugsAndImprovements = VersionFeature(
  //   type: FeatureType.typeBugFix,
  //   description: 'Various bug fixes and improvements',
  // );
  // static VersionFeature improvedData = VersionFeature(
  //   type: FeatureType.typeDataFix,
  //   description: 'Improved plate data and locations',
  // );

  // 1.10.1 - 🇪🇹 Ethiopia diplomatic plates added, 🇧🇬 Bulgaria electric/military added

  // static final List<VersionDescription> allVersionUpdates = [
  //   VersionDescription(
  //     releaseNumber: 185,
  //     versionNumber: '1.10.1',
  //     description: 'Plates and bugfixes',
  //     features: [
  //       VersionFeature(
  //         type: FeatureType.typeDataFix,
  //         title: '🇪🇹 Ethiopia',
  //         description: 'Added diplomatic plates',
  //       ),
  //       VersionFeature(
  //         type: FeatureType.typeDataFix,
  //         title: '🇧🇬 Bulgaria',
  //         description: 'Electric/miliary added, ',
  //       ),
  //       improvedData,
  //       // generalBugsAndImprovements,
  //     ],
  //   ),
  //   // 1.10 - Added 🇲🇾 Malaysia (incl. taxis, diplomatic), 🇹🇭 Thailand (Trucks/busses and diplomatic). Added 🇰🇬 Kyrgyzstan old series and diplomatic (#234), 🇺🇾 Added cities in Maldonado dept, removed B in old series from Plateopedia
  //   //      Supporting different types of diplomatic (embassies, consulates, honorary consulates and international organizations), added taxi car type
  //   //       Added 🇮🇶 Iraq (#88) - which is new since 2024/5, 🇰🇬 now displays the capitals, 🇭🇷 Zupanja is now Županja
  //   //        b2 - 🇵🇹 200 is EU (before it displayed as embassy of null)

  //   VersionDescription(
  //     releaseNumber: 184,
  //     versionNumber: '1.10',
  //     description: 'Diplomatic Plates',
  //     features: [
  //       VersionFeature(
  //         type: FeatureType.typeDataFix,
  //         title: 'New Countries',
  //         description:
  //             '🇲🇾 Malaysia (#87), including embassies, 🇹🇭 Thailand (#88, Trucks/busses and diplomatic) and 🇮🇶 Iraq (#89)',
  //       ),
  //       VersionFeature(
  //         type: FeatureType.typeDataFix,
  //         title: 'Data',
  //         description:
  //             '🇰🇬 Kyrgyzstan old series and diplomatic added, 🇺🇾 Uruguay Updated',
  //       ),
  //       improvedData,
  //       generalBugsAndImprovements,
  //     ],
  //   ),

  // ];
}
