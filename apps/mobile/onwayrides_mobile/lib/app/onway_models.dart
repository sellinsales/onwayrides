import 'package:flutter/material.dart';

enum ServiceType {
  rideShare,
  taxi,
  bikeTaxi,
  rickshawTaxi,
  rentCar,
  cityToCity,
  schoolOffice,
  foodDelivery,
  courier,
  airport,
  prebooking,
}

class OnWayService {
  const OnWayService({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.icon,
    required this.eta,
    this.negotiable = false,
  });

  final ServiceType type;
  final String title;
  final String subtitle;
  final String imageAsset;
  final IconData icon;
  final String eta;
  final bool negotiable;
}

class FareOption {
  const FareOption({
    required this.title,
    required this.capacity,
    required this.eta,
    required this.priceLabel,
    this.recommended = false,
    this.negotiable = false,
  });

  final String title;
  final String capacity;
  final String eta;
  final String priceLabel;
  final bool recommended;
  final bool negotiable;
}

class OnWayPlaceSuggestion {
  const OnWayPlaceSuggestion({
    required this.title,
    required this.addressLine,
    required this.icon,
    this.badge,
    this.isSaved = false,
  });

  final String title;
  final String addressLine;
  final IconData icon;
  final String? badge;
  final bool isSaved;
}

class OnWayContextualSuggestion {
  const OnWayContextualSuggestion({
    required this.title,
    required this.description,
    required this.icon,
    required this.serviceType,
    this.ctaLabel = 'Use this flow',
  });

  final String title;
  final String description;
  final IconData icon;
  final ServiceType serviceType;
  final String ctaLabel;
}

class DriverProfile {
  const DriverProfile({
    required this.name,
    required this.rating,
    required this.vehicle,
    required this.plate,
    required this.phone,
    required this.distanceAway,
    required this.eta,
    required this.avatarAsset,
  });

  final String name;
  final String rating;
  final String vehicle;
  final String plate;
  final String phone;
  final String distanceAway;
  final String eta;
  final String avatarAsset;
}

class ActiveTrip {
  const ActiveTrip({
    this.bookingId,
    this.bookingReference,
    this.status,
    required this.serviceTitle,
    required this.pickup,
    required this.destination,
    required this.statusLine,
    required this.routeLine,
    required this.paymentLabel,
    required this.fareLabel,
    this.driver,
  });

  final int? bookingId;
  final String? bookingReference;
  final String? status;
  final String serviceTitle;
  final String pickup;
  final String destination;
  final String statusLine;
  final String routeLine;
  final String paymentLabel;
  final String fareLabel;
  final DriverProfile? driver;
}

class TripHistoryItem {
  const TripHistoryItem({
    this.reference,
    required this.title,
    required this.dateLabel,
    required this.route,
    required this.amount,
    required this.status,
  });

  final String? reference;
  final String title;
  final String dateLabel;
  final String route;
  final String amount;
  final String status;
}

class OnWayTripFeed {
  const OnWayTripFeed({required this.activeTrip, required this.history});

  final ActiveTrip? activeTrip;
  final List<TripHistoryItem> history;
}

class OnWaySelectOption {
  const OnWaySelectOption({
    required this.id,
    required this.label,
    this.slug,
    this.meta = const {},
  });

  final int id;
  final String label;
  final String? slug;
  final Map<String, Object?> meta;
}

class OnWayVehicleTypeOption {
  const OnWayVehicleTypeOption({
    required this.id,
    required this.vehicleCategoryId,
    required this.label,
    this.seats,
  });

  final int id;
  final int vehicleCategoryId;
  final String label;
  final int? seats;
}

class OnWayVehicleModelOption {
  const OnWayVehicleModelOption({
    required this.id,
    required this.vehicleMakeId,
    required this.label,
  });

  final int id;
  final int vehicleMakeId;
  final String label;
}

class OnWayDriverDocumentTypeOption {
  const OnWayDriverDocumentTypeOption({
    required this.value,
    required this.label,
    this.sampleHint,
    this.isRequired = false,
    this.sortOrder = 999,
  });

  final String value;
  final String label;
  final String? sampleHint;
  final bool isRequired;
  final int sortOrder;
}

class OnWayDriverDocumentSummary {
  const OnWayDriverDocumentSummary({
    required this.id,
    required this.documentType,
    required this.status,
    this.documentLabel,
    this.statusLabel,
    this.expiryDate,
    this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
    this.updatedAt,
    this.isRequired = false,
    this.canResubmit = false,
    this.sampleHint,
    this.sortOrder = 999,
  });

  final int id;
  final String documentType;
  final String status;
  final String? documentLabel;
  final String? statusLabel;
  final String? expiryDate;
  final String? submittedAt;
  final String? reviewedAt;
  final String? rejectionReason;
  final String? updatedAt;
  final bool isRequired;
  final bool canResubmit;
  final String? sampleHint;
  final int sortOrder;

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected' || status == 'expired';
  bool get isPendingReview => status == 'pending';

  String get effectiveLabel {
    if (documentLabel != null && documentLabel!.trim().isNotEmpty) {
      return documentLabel!;
    }

    final normalized = documentType.replaceAll('_', ' ');
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  String get effectiveStatusLabel {
    if (statusLabel != null && statusLabel!.trim().isNotEmpty) {
      return statusLabel!;
    }

    final normalized = status.replaceAll('_', ' ');
    return normalized[0].toUpperCase() + normalized.substring(1);
  }
}

class OnWayDriverOnboardingChecklist {
  const OnWayDriverOnboardingChecklist({
    required this.stage,
    required this.nextAction,
    required this.profileComplete,
    required this.vehicleComplete,
    required this.allRequiredSubmitted,
    required this.allRequiredApproved,
    required this.activationReady,
    required this.reviewPending,
    required this.requiredDocumentTypes,
    required this.requiredDocumentsTotal,
    required this.requiredDocumentsSubmitted,
    required this.requiredDocumentsApproved,
    required this.requiredDocumentsRejected,
  });

  final String stage;
  final String nextAction;
  final bool profileComplete;
  final bool vehicleComplete;
  final bool allRequiredSubmitted;
  final bool allRequiredApproved;
  final bool activationReady;
  final bool reviewPending;
  final List<String> requiredDocumentTypes;
  final int requiredDocumentsTotal;
  final int requiredDocumentsSubmitted;
  final int requiredDocumentsApproved;
  final int requiredDocumentsRejected;
}

class OnWayVehicleDraft {
  const OnWayVehicleDraft({
    required this.id,
    this.plateNumber,
    this.vehicleCategoryId,
    this.vehicleTypeId,
    this.vehicleMakeId,
    this.vehicleModelId,
    this.yearOfManufacture,
    this.seats,
    this.fuelType,
    this.status,
  });

  final int id;
  final String? plateNumber;
  final int? vehicleCategoryId;
  final int? vehicleTypeId;
  final int? vehicleMakeId;
  final int? vehicleModelId;
  final int? yearOfManufacture;
  final int? seats;
  final String? fuelType;
  final String? status;
}

class OnWayDriverApplication {
  const OnWayDriverApplication({
    required this.driverProfileId,
    required this.driverCode,
    required this.status,
    required this.onboardingStatus,
    required this.cityId,
    required this.isOnline,
    required this.isBusy,
    required this.acceptsCash,
    required this.acceptsWallet,
    required this.acceptsCard,
    required this.ratingAverage,
    required this.ratingCount,
    required this.tripsCompleted,
    required this.serviceTypeIds,
    required this.documents,
    required this.checklist,
    this.licenseNumber,
    this.notes,
    this.vehicle,
  });

  final int driverProfileId;
  final String driverCode;
  final String status;
  final String onboardingStatus;
  final int? cityId;
  final bool isOnline;
  final bool isBusy;
  final bool acceptsCash;
  final bool acceptsWallet;
  final bool acceptsCard;
  final double ratingAverage;
  final int ratingCount;
  final int tripsCompleted;
  final List<int> serviceTypeIds;
  final List<OnWayDriverDocumentSummary> documents;
  final OnWayDriverOnboardingChecklist checklist;
  final String? licenseNumber;
  final String? notes;
  final OnWayVehicleDraft? vehicle;

  bool get isApproved => status == 'active' && onboardingStatus == 'approved';

  bool get needsReview =>
      onboardingStatus == 'documents_pending' ||
      onboardingStatus == 'review' ||
      status == 'pending';

  String get statusLabel {
    final value = onboardingStatus == 'approved' ? status : onboardingStatus;
    final normalized = value.replaceAll('_', ' ');

    return normalized[0].toUpperCase() + normalized.substring(1);
  }
}

class OnWayDriverWorkspaceUser {
  const OnWayDriverWorkspaceUser({
    required this.id,
    required this.fullName,
    required this.role,
    this.email,
    this.phone,
    this.countryCode,
    this.nationalIdNumber,
  });

  final int id;
  final String fullName;
  final String role;
  final String? email;
  final String? phone;
  final String? countryCode;
  final String? nationalIdNumber;
}

class OnWayDriverWorkspaceBundle {
  const OnWayDriverWorkspaceBundle({
    required this.user,
    required this.cities,
    required this.serviceTypes,
    required this.vehicleCategories,
    required this.vehicleTypes,
    required this.vehicleMakes,
    required this.vehicleModels,
    required this.documentTypes,
    required this.driverSamples,
    required this.driverDemoAccessEnabled,
    required this.canActivateDriverDemoAccess,
    this.driverApplication,
  });

  final OnWayDriverWorkspaceUser user;
  final List<OnWaySelectOption> cities;
  final List<OnWaySelectOption> serviceTypes;
  final List<OnWaySelectOption> vehicleCategories;
  final List<OnWayVehicleTypeOption> vehicleTypes;
  final List<OnWaySelectOption> vehicleMakes;
  final List<OnWayVehicleModelOption> vehicleModels;
  final List<OnWayDriverDocumentTypeOption> documentTypes;
  final Map<String, String> driverSamples;
  final bool driverDemoAccessEnabled;
  final bool canActivateDriverDemoAccess;
  final OnWayDriverApplication? driverApplication;
}

class DriverStat {
  const DriverStat({
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final String value;
  final String delta;
}

class DriverRequest {
  const DriverRequest({
    this.id,
    this.reference,
    required this.serviceTitle,
    required this.riderName,
    required this.pickup,
    required this.dropoff,
    required this.fareLabel,
    required this.distanceLabel,
    required this.paymentLabel,
    required this.canCounter,
    this.status = 'pending',
    this.statusLine = 'Request ready for driver action.',
  });

  final int? id;
  final String? reference;
  final String serviceTitle;
  final String riderName;
  final String pickup;
  final String dropoff;
  final String fareLabel;
  final String distanceLabel;
  final String paymentLabel;
  final bool canCounter;
  final String status;
  final String statusLine;
}

class OnWayDriverCurrentTrip {
  const OnWayDriverCurrentTrip({
    required this.id,
    required this.reference,
    required this.serviceTitle,
    required this.riderName,
    required this.pickup,
    required this.dropoff,
    required this.status,
    required this.statusLabel,
    required this.fareLabel,
    required this.paymentLabel,
    this.riderPhone,
  });

  final int id;
  final String reference;
  final String serviceTitle;
  final String riderName;
  final String pickup;
  final String dropoff;
  final String status;
  final String statusLabel;
  final String fareLabel;
  final String paymentLabel;
  final String? riderPhone;

  String get nextPrimaryActionLabel {
    switch (status) {
      case 'accepted':
        return 'Mark arrived';
      case 'arriving':
        return 'Start trip';
      case 'in_progress':
        return 'Complete trip';
      default:
        return 'Refresh';
    }
  }

  String? get nextPrimaryStatus {
    switch (status) {
      case 'accepted':
        return 'arriving';
      case 'arriving':
        return 'in_progress';
      case 'in_progress':
        return 'completed';
      default:
        return null;
    }
  }
}

class OnWayDriverDispatchFeed {
  const OnWayDriverDispatchFeed({
    required this.isOnline,
    required this.isBusy,
    required this.requests,
    this.currentTrip,
  });

  final bool isOnline;
  final bool isBusy;
  final List<DriverRequest> requests;
  final OnWayDriverCurrentTrip? currentTrip;
}

class FleetMetric {
  const FleetMetric({
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final String value;
  final String delta;
}

class FleetDriver {
  const FleetDriver({
    required this.name,
    required this.status,
    required this.rating,
    required this.vehicle,
    required this.services,
  });

  final String name;
  final String status;
  final String rating;
  final String vehicle;
  final List<String> services;
}

class FleetVehicle {
  const FleetVehicle({
    required this.plate,
    required this.type,
    required this.assignedDriver,
    required this.status,
  });

  final String plate;
  final String type;
  final String assignedDriver;
  final String status;
}
