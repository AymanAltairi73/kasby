import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/tour_service.dart';
import 'package:kasby/routes/app_routes.dart';

/// Legacy route shim — redirects to home and enables onboarding for replay.
class GuidedTourView extends StatefulWidget {
  const GuidedTourView({super.key});

  @override
  State<GuidedTourView> createState() => _GuidedTourViewState();
}

class _GuidedTourViewState extends State<GuidedTourView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await TourService.enableAutoToursForNewUser();
      if (mounted) Get.offAllNamed(Routes.home);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
