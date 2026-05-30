import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../auth/onway_auth_service.dart';
import '../auth/onway_auth_session.dart';
import '../onway_map.dart';
import '../onway_mock_data.dart';
import '../onway_models.dart';
import '../onway_theme.dart';
import '../onway_widgets.dart';

class DriverModeScreen extends StatefulWidget {
  const DriverModeScreen({
    super.key,
    required this.authService,
    required this.stats,
    required this.requests,
    required this.services,
    required this.onOpenFleetOwner,
    this.session,
    this.previewMode = false,
  });

  final OnWayAuthService? authService;
  final OnWayAuthSession? session;
  final bool previewMode;
  final List<DriverStat> stats;
  final List<DriverRequest> requests;
  final List<OnWayService> services;
  final VoidCallback onOpenFleetOwner;

  @override
  State<DriverModeScreen> createState() => _DriverModeScreenState();
}

class _DriverModeScreenState extends State<DriverModeScreen> {
  static const _dispatchRefreshInterval = Duration(seconds: 10);

  Future<OnWayDriverWorkspaceBundle>? _workspaceFuture;
  Future<OnWayDriverDispatchFeed>? _dispatchFuture;
  Timer? _dispatchTimer;
  StreamSubscription<OnWayRealtimeEvent>? _realtimeSubscription;

  final _licenseController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _plateController = TextEditingController();
  final _yearController = TextEditingController();
  final _seatsController = TextEditingController();
  final _notesController = TextEditingController();

  bool _editingApplication = false;
  bool _formHydrated = false;
  bool _savingDraft = false;
  bool _activatingDemoAccess = false;
  bool _updatingMode = false;
  bool _requestActionBusy = false;
  String? _uploadingDocumentType;

  int? _selectedCityId;
  int? _selectedVehicleCategoryId;
  int? _selectedVehicleTypeId;
  int? _selectedVehicleMakeId;
  int? _selectedVehicleModelId;
  String _fuelType = 'petrol';
  String _availability = 'full_time';
  String _licenseStatus = 'ready';
  bool _driverOnline = false;
  Set<int> _selectedServiceIds = <int>{};

  @override
  void initState() {
    super.initState();
    if (!widget.previewMode) {
      _bindRealtimeUpdates();
      _workspaceFuture = widget.authService!.fetchDriverWorkspace();
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _dispatchTimer?.cancel();
    _licenseController.dispose();
    _nationalIdController.dispose();
    _plateController.dispose();
    _yearController.dispose();
    _seatsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _bindRealtimeUpdates() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = widget.authService?.realtimeEvents.listen((event) {
      if (!mounted) {
        return;
      }

      if (event.channel != 'driver_dispatch' &&
          event.channel != 'trip_updates' &&
          event.channel != 'driver_onboarding') {
        return;
      }

      setState(() {
        if (event.channel == 'driver_onboarding') {
          _formHydrated = false;
          _workspaceFuture = widget.authService!.fetchDriverWorkspace();
        } else {
          _dispatchFuture = widget.authService!.fetchDriverRequests();
        }
      });
    });
  }

  Future<void> _reloadWorkspace() async {
    if (widget.previewMode) {
      return;
    }

    setState(() {
      _formHydrated = false;
      _dispatchFuture = null;
      _workspaceFuture = widget.authService!.fetchDriverWorkspace();
    });
  }

  Future<void> _activateDemoDriverAccess() async {
    if (widget.previewMode || _activatingDemoAccess) {
      return;
    }

    setState(() => _activatingDemoAccess = true);

    try {
      await widget.authService!.activateDriverDemoAccess();
      if (!mounted) {
        return;
      }

      _showMessage('Temporary demo driver access is now active.');
      setState(() {
        _formHydrated = false;
        _dispatchFuture = null;
        _workspaceFuture = widget.authService!.fetchDriverWorkspace();
      });
    } on OnWayAuthException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _activatingDemoAccess = false);
      }
    }
  }

  void _hydrateForm(OnWayDriverWorkspaceBundle bundle) {
    if (_formHydrated) {
      return;
    }

    final application = bundle.driverApplication;
    _selectedCityId = application?.cityId;
    _selectedVehicleCategoryId = application?.vehicle?.vehicleCategoryId;
    _selectedVehicleTypeId = application?.vehicle?.vehicleTypeId;
    _selectedVehicleMakeId = application?.vehicle?.vehicleMakeId;
    _selectedVehicleModelId = application?.vehicle?.vehicleModelId;
    _fuelType = application?.vehicle?.fuelType ?? 'petrol';
    _driverOnline = application?.isOnline ?? false;
    _selectedServiceIds = {...application?.serviceTypeIds ?? const <int>[]};
    _licenseController.text = application?.licenseNumber ?? '';
    _nationalIdController.text = bundle.user.nationalIdNumber ?? '';
    _plateController.text = application?.vehicle?.plateNumber ?? '';
    _yearController.text =
        application?.vehicle?.yearOfManufacture?.toString() ?? '';
    _seatsController.text = application?.vehicle?.seats?.toString() ?? '';
    _notesController.text = application?.notes ?? '';
    _editingApplication = application == null || !application.isApproved;
    if (application?.isApproved ?? false) {
      _dispatchFuture ??= widget.authService!.fetchDriverRequests();
      _dispatchTimer ??= Timer.periodic(_dispatchRefreshInterval, (_) {
        if (!mounted || widget.previewMode) {
          return;
        }
        setState(() {
          _dispatchFuture = widget.authService!.fetchDriverRequests();
        });
      });
    } else {
      _dispatchTimer?.cancel();
      _dispatchTimer = null;
      _dispatchFuture = null;
    }
    _formHydrated = true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.previewMode) {
      return _PreviewDriverMode(
        stats: widget.stats,
        requests: widget.requests,
        services: widget.services,
        onOpenFleetOwner: widget.onOpenFleetOwner,
      );
    }

    return FutureBuilder<OnWayDriverWorkspaceBundle>(
      future: _workspaceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _DriverLoadingScreen();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _DriverErrorScreen(
            message: snapshot.error is OnWayAuthException
                ? (snapshot.error as OnWayAuthException).message
                : 'Unable to load driver mode right now.',
            onRetry: _reloadWorkspace,
          );
        }

        final bundle = snapshot.data!;
        _hydrateForm(bundle);

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            children: [
              BrandHeader(
                caption: 'Drive, manage requests, and track your progress',
                trailing: IconButton(
                  onPressed: _reloadWorkspace,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              const SizedBox(height: 22),
              _buildHero(context, bundle),
              const SizedBox(height: 24),
              if (bundle.driverApplication?.isApproved ?? false)
                ..._buildApprovedDriverPanels(context, bundle)
              else
                ..._buildApplicationPanels(context, bundle),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHero(BuildContext context, OnWayDriverWorkspaceBundle bundle) {
    final application = bundle.driverApplication;
    final statusLabel = application == null
        ? 'Not onboarded'
        : application.isApproved
        ? (_driverOnline ? 'Online now' : 'Approved • Offline')
        : application.statusLabel;
    final title = application == null
        ? 'Drive with the same account you already use'
        : application.isApproved
        ? (_driverOnline
              ? 'Driver mode is live and listening for nearby demand'
              : 'You are approved and ready to go online')
        : 'Your driver onboarding is in progress';
    final description = application == null
        ? 'Apply to drive, manage your documents, and stay ready for requests without switching apps.'
        : application.isApproved
        ? (_driverOnline
              ? 'Focus on live requests, your current trip, and your enabled services. Everything else stays secondary.'
              : 'Review your enabled services, then go online only when you want to start taking requests.')
        : _statusDescription(application);

    return OnWayPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ModeChip(label: 'Rider', selected: true),
              ModeChip(
                label: application?.isApproved == true ? 'Drive' : 'Apply',
                selected: application?.isApproved == true,
              ),
              ModeChip(label: statusLabel, selected: false),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _inlineStat(
                context,
                application?.driverCode ?? 'Not issued yet',
                'Driver ID',
              ),
              _inlineStat(
                context,
                '${application?.documents.length ?? 0}',
                'Documents',
              ),
              _inlineStat(context, '${_selectedServiceIds.length}', 'Services'),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildApplicationPanels(
    BuildContext context,
    OnWayDriverWorkspaceBundle bundle,
  ) {
    final application = bundle.driverApplication;
    final checklist = application?.checklist;
    final requiredUploaded = checklist?.requiredDocumentsSubmitted ?? 0;
    final requiredTotal =
        checklist?.requiredDocumentsTotal ??
        bundle.documentTypes.where((document) => document.isRequired).length;

    return [
      SectionHeading(
        title: application == null
            ? 'Start your driver application'
            : 'Continue your driver application',
        subtitle: application == null
            ? 'Complete your profile, add a vehicle, upload documents, and submit for review.'
            : 'Pick up where you left off and follow the next step shown below.',
        action: TextButton(
          onPressed: () =>
              setState(() => _editingApplication = !_editingApplication),
          child: Text(_editingApplication ? 'Hide form' : 'Open form'),
        ),
      ),
      const SizedBox(height: 14),
      OnWayPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              application == null ? 'Application status' : 'Your driver status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              application == null
                  ? 'You can keep booking rides while you complete your driver application.'
                  : checklist?.nextAction ?? _statusDescription(application),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _statusBadge(application?.statusLabel ?? 'Not started'),
                if (application != null)
                  _statusBadge(
                    '$requiredUploaded of $requiredTotal required documents uploaded',
                  ),
                if (checklist != null) _statusBadge(_pretty(checklist.stage)),
                if (bundle.driverDemoAccessEnabled)
                  _statusBadge('Demo access enabled'),
              ],
            ),
            if (bundle.canActivateDriverDemoAccess &&
                !(application?.isApproved ?? false)) ...[
              const SizedBox(height: 16),
              OnWayPanel(
                padding: const EdgeInsets.all(14),
                backgroundColor: OnWayTheme.slate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test driver mode before approval',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bundle.driverDemoAccessEnabled
                          ? 'Demo access is active on your account. You can explore live driver tools while you finish your real documents.'
                          : 'Turn on temporary demo access to try requests, online mode, and live driver screens before your real documents are approved.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: bundle.driverDemoAccessEnabled
                          ? null
                          : _activatingDemoAccess
                          ? null
                          : _activateDemoDriverAccess,
                      icon: const Icon(Icons.verified_user_rounded),
                      label: Text(
                        bundle.driverDemoAccessEnabled
                            ? 'Demo access active'
                            : _activatingDemoAccess
                            ? 'Activating demo access...'
                            : 'Activate demo driver access',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _progressTile(
                    context,
                    '1',
                    'Profile',
                    complete: checklist?.profileComplete ?? application != null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _progressTile(
                    context,
                    '2',
                    'Vehicle',
                    complete:
                        checklist?.vehicleComplete ??
                        application?.vehicle != null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _progressTile(
                    context,
                    '3',
                    'Documents',
                    complete:
                        checklist?.allRequiredSubmitted ??
                        (application?.documents.isNotEmpty ?? false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _progressTile(
                    context,
                    '4',
                    'Review',
                    complete:
                        checklist?.allRequiredApproved ??
                        application?.isApproved ??
                        false,
                  ),
                ),
              ],
            ),
            if (application != null) ...[
              const SizedBox(height: 16),
              Text(
                _stageHeadline(checklist?.stage ?? 'profile'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(_stageDescription(application)),
            ],
          ],
        ),
      ),
      const SizedBox(height: 24),
      if (_editingApplication) ...[
        _buildApplicationForm(context, bundle),
        const SizedBox(height: 24),
      ],
      _buildDocumentChecklist(context, bundle),
    ];
  }

  List<Widget> _buildApprovedDriverPanels(
    BuildContext context,
    OnWayDriverWorkspaceBundle bundle,
  ) {
    final application = bundle.driverApplication!;

    return [
      SectionHeading(
        title: _driverOnline ? 'Live driver mode' : 'Approved driver mode',
        subtitle: _driverOnline
            ? 'Stay focused on incoming requests, the current trip, and quick status changes.'
            : 'You are approved. Pick your services and go online only when you want to earn.',
      ),
      const SizedBox(height: 14),
      OnWayPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _driverOnline ? 'You are online' : 'Currently offline',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _driverOnline
                            ? 'You will receive requests for the services selected below.'
                            : 'Pause requests when you want to ride as a customer or step away from dispatch.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _driverOnline,
                  activeThumbColor: OnWayTheme.yellow,
                  onChanged: _updatingMode
                      ? null
                      : (value) async {
                          setState(() => _driverOnline = value);
                          await _saveDriverMode();
                        },
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _updatingMode ? null : _saveDriverMode,
              child: Text(
                _updatingMode ? 'Updating mode...' : 'Save driver mode',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _buildDispatchPanel(context),
      const SizedBox(height: 24),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth > 760
              ? (constraints.maxWidth - 48) / 4
              : (constraints.maxWidth - 16) / 2;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: width,
                child: MetricTile(
                  label: 'Trips completed',
                  value: '${application.tripsCompleted}',
                  delta: application.isBusy ? 'Busy now' : 'Ready',
                ),
              ),
              SizedBox(
                width: width,
                child: MetricTile(
                  label: 'Driver rating',
                  value: application.ratingAverage.toStringAsFixed(1),
                  delta: '${application.ratingCount} reviews',
                ),
              ),
              SizedBox(
                width: width,
                child: MetricTile(
                  label: 'Enabled services',
                  value: '${_selectedServiceIds.length}',
                  delta: 'Editable',
                ),
              ),
              SizedBox(
                width: width,
                child: MetricTile(
                  label: 'Documents',
                  value: '${application.documents.length}',
                  delta: 'On file',
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 24),
      const SectionHeading(
        title: 'Accept these services',
        subtitle: 'Choose where you want demand to reach you.',
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: bundle.serviceTypes
            .map((service) {
              final selected = _selectedServiceIds.contains(service.id);
              return FilterChip(
                label: Text(service.label),
                selected: selected,
                onSelected: _updatingMode
                    ? null
                    : (value) {
                        setState(() {
                          if (value) {
                            _selectedServiceIds.add(service.id);
                          } else {
                            _selectedServiceIds.remove(service.id);
                          }
                        });
                      },
              );
            })
            .toList(growable: false),
      ),
      const SizedBox(height: 24),
      const OnWayPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dispatch operations',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 10),
            Text(
              'Manage nearby requests, active trips, and your service availability from one place.',
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildDispatchPanel(BuildContext context) {
    return FutureBuilder<OnWayDriverDispatchFeed>(
      future: _dispatchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const OnWayPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live request queue',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 10),
                Text('Refreshing nearby requests...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          final message = snapshot.error is OnWayAuthException
              ? (snapshot.error as OnWayAuthException).message
              : 'Unable to load live driver requests.';

          return OnWayPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live request queue',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(message),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _dispatchFuture = widget.authService!
                          .fetchDriverRequests();
                    });
                  },
                  child: const Text('Retry queue'),
                ),
              ],
            ),
          );
        }

        final feed =
            snapshot.data ??
            const OnWayDriverDispatchFeed(
              isOnline: false,
              isBusy: false,
              requests: [],
            );

        return OnWayPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live request queue',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                feed.isOnline
                    ? 'Nearby requests refresh automatically while you stay online.'
                    : 'Go online first to start receiving nearby rider demand.',
              ),
              const SizedBox(height: 18),
              _buildDispatchMapCard(context, feed),
              if (feed.currentTrip != null) ...[
                const SizedBox(height: 18),
                _currentTripCard(context, feed.currentTrip!),
              ],
              if (feed.requests.isNotEmpty) ...[
                const SizedBox(height: 18),
                for (final request in feed.requests) ...[
                  _driverRequestCard(context, request),
                  const SizedBox(height: 12),
                ],
              ] else if (feed.currentTrip == null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: OnWayTheme.slate,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    feed.isOnline
                        ? 'No nearby requests right now. Keep driver mode online and the queue will refresh automatically.'
                        : 'Driver mode is offline, so no live requests are being pulled.',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDispatchMapCard(
    BuildContext context,
    OnWayDriverDispatchFeed feed,
  ) {
    final currentTrip = feed.currentTrip;
    final pickupCoordinate =
        currentTrip?.pickupCoordinate ??
        (currentTrip != null
            ? OnWayMockData.coordinateForAddress(currentTrip.pickup)
            : null);
    final dropoffCoordinate =
        currentTrip?.dropoffCoordinate ??
        (currentTrip != null
            ? OnWayMockData.coordinateForAddress(currentTrip.dropoff)
            : null);
    final route = pickupCoordinate != null && dropoffCoordinate != null
        ? buildRoutePath(pickupCoordinate, dropoffCoordinate)
        : const <OnWayCoordinate>[];
    final markers = <OnWayMapMarkerSpec>[
      const OnWayMapMarkerSpec(
        coordinate: OnWayMockData.driverLivePosition,
        icon: Icons.navigation_rounded,
        label: 'You',
        color: Color(0xFF91F2C0),
      ),
      if (pickupCoordinate != null)
        OnWayMapMarkerSpec(
          coordinate: pickupCoordinate,
          icon: Icons.person_pin_circle_rounded,
          label: currentTrip == null ? 'Pickup' : 'Rider',
          color: Colors.white,
        ),
      if (dropoffCoordinate != null)
        OnWayMapMarkerSpec(
          coordinate: dropoffCoordinate,
          icon: Icons.flag_rounded,
          label: 'Dropoff',
        ),
      if (currentTrip == null)
        ...feed.requests
            .take(3)
            .map(
              (request) => OnWayMapMarkerSpec(
                coordinate:
                    request.pickupCoordinate ??
                    OnWayMockData.coordinateForAddress(request.pickup),
                icon: Icons.local_taxi_rounded,
                label: request.serviceTitle,
                size: 36,
              ),
            ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currentTrip == null ? 'Dispatch map' : 'Active trip map',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        OnWayMapSurface(
          height: 210,
          interactive: false,
          markers: markers,
          route: route,
        ),
      ],
    );
  }

  Widget _buildApplicationForm(
    BuildContext context,
    OnWayDriverWorkspaceBundle bundle,
  ) {
    final filteredVehicleTypes = _selectedVehicleCategoryId == null
        ? bundle.vehicleTypes
        : bundle.vehicleTypes
              .where(
                (type) => type.vehicleCategoryId == _selectedVehicleCategoryId,
              )
              .toList(growable: false);
    final filteredVehicleModels = _selectedVehicleMakeId == null
        ? bundle.vehicleModels
        : bundle.vehicleModels
              .where((model) => model.vehicleMakeId == _selectedVehicleMakeId)
              .toList(growable: false);

    return OnWayPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Driver application',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Keep the form short and standard: identity, service choices, vehicle details, then document review.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            initialValue: _selectedCityId,
            items: bundle.cities
                .map(
                  (city) => DropdownMenuItem<int>(
                    value: city.id,
                    child: Text(city.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() => _selectedCityId = value),
            decoration: const InputDecoration(labelText: 'Operating city'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nationalIdController,
            decoration: const InputDecoration(
              labelText: 'National ID / CNIC',
              hintText: 'Enter your national ID number',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _licenseController,
            decoration: const InputDecoration(
              labelText: 'Driver license number',
              hintText: 'Enter your license number',
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Services you want to drive',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: bundle.serviceTypes
                .map((service) {
                  final selected = _selectedServiceIds.contains(service.id);
                  return FilterChip(
                    label: Text(service.label),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedServiceIds.add(service.id);
                        } else {
                          _selectedServiceIds.remove(service.id);
                        }
                      });
                    },
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 18),
          Text('Availability', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _choiceChip(
                label: 'Full time',
                selected: _availability == 'full_time',
                onSelected: () => setState(() => _availability = 'full_time'),
              ),
              _choiceChip(
                label: 'Part time',
                selected: _availability == 'part_time',
                onSelected: () => setState(() => _availability = 'part_time'),
              ),
              _choiceChip(
                label: 'Weekends',
                selected: _availability == 'weekends',
                onSelected: () => setState(() => _availability = 'weekends'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'License readiness',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _choiceChip(
                label: 'Ready',
                selected: _licenseStatus == 'ready',
                onSelected: () => setState(() => _licenseStatus = 'ready'),
              ),
              _choiceChip(
                label: 'Renewing',
                selected: _licenseStatus == 'renewing',
                onSelected: () => setState(() => _licenseStatus = 'renewing'),
              ),
              _choiceChip(
                label: 'Need help',
                selected: _licenseStatus == 'need_help',
                onSelected: () => setState(() => _licenseStatus = 'need_help'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            initialValue: _selectedVehicleCategoryId,
            items: bundle.vehicleCategories
                .map(
                  (category) => DropdownMenuItem<int>(
                    value: category.id,
                    child: Text(category.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              setState(() {
                _selectedVehicleCategoryId = value;
                _selectedVehicleTypeId = null;
              });
            },
            decoration: const InputDecoration(labelText: 'Vehicle category'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _selectedVehicleTypeId,
            items: filteredVehicleTypes
                .map(
                  (type) => DropdownMenuItem<int>(
                    value: type.id,
                    child: Text(type.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) =>
                setState(() => _selectedVehicleTypeId = value),
            decoration: const InputDecoration(labelText: 'Vehicle type'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _selectedVehicleMakeId,
            items: bundle.vehicleMakes
                .map(
                  (make) => DropdownMenuItem<int>(
                    value: make.id,
                    child: Text(make.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              setState(() {
                _selectedVehicleMakeId = value;
                _selectedVehicleModelId = null;
              });
            },
            decoration: const InputDecoration(labelText: 'Vehicle make'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _selectedVehicleModelId,
            items: filteredVehicleModels
                .map(
                  (model) => DropdownMenuItem<int>(
                    value: model.id,
                    child: Text(model.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) =>
                setState(() => _selectedVehicleModelId = value),
            decoration: const InputDecoration(labelText: 'Vehicle model'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _plateController,
            decoration: const InputDecoration(
              labelText: 'Plate number',
              hintText: 'Enter your vehicle plate number',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Year'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _seatsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Seats'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Fuel type', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option in const [
                'petrol',
                'diesel',
                'hybrid',
                'electric',
                'cng',
                'other',
              ])
                _choiceChip(
                  label: _pretty(option),
                  selected: _fuelType == option,
                  onSelected: () => setState(() => _fuelType = option),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText:
                  'Anything support should know about your vehicle or route availability',
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _savingDraft
                ? null
                : () => _saveApplicationDraft(bundle),
            child: Text(_savingDraft ? 'Saving draft...' : 'Save driver draft'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentChecklist(
    BuildContext context,
    OnWayDriverWorkspaceBundle bundle,
  ) {
    final application = bundle.driverApplication;
    final checklist = application?.checklist;
    final existingByType = {
      for (final document
          in application?.documents ?? const <OnWayDriverDocumentSummary>[])
        document.documentType: document,
    };
    final documentTypes = [...bundle.documentTypes]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final uploadsLocked = application == null;

    return OnWayPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documents and review',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            uploadsLocked
                ? 'Save your core driver profile first. Document upload opens immediately after that.'
                : (checklist?.nextAction ??
                      'Upload the missing documents and keep an eye on review updates here.'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (application != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Required documents approved: ${checklist?.requiredDocumentsApproved ?? 0} / ${checklist?.requiredDocumentsTotal ?? 0}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 14),
          ],
          for (final type in documentTypes) ...[
            _documentRow(
              context,
              type,
              existingByType[type.value],
              uploadsLocked: uploadsLocked,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Future<void> _saveApplicationDraft(OnWayDriverWorkspaceBundle bundle) async {
    if (_selectedCityId == null) {
      _showMessage('Choose your operating city first.');
      return;
    }
    if (_licenseController.text.trim().isEmpty) {
      _showMessage('Enter your driver license number.');
      return;
    }
    if (_nationalIdController.text.trim().isEmpty) {
      _showMessage('Enter your national ID / CNIC.');
      return;
    }
    if (_selectedServiceIds.isEmpty) {
      _showMessage('Select at least one service you want to drive.');
      return;
    }

    setState(() => _savingDraft = true);
    try {
      await widget.authService!.saveDriverApplicationDraft(
        cityId: _selectedCityId!,
        licenseNumber: _licenseController.text,
        nationalIdNumber: _nationalIdController.text,
        serviceTypeIds: _selectedServiceIds.toList()..sort(),
        vehicleCategoryId: _selectedVehicleCategoryId,
        vehicleTypeId: _selectedVehicleTypeId,
        vehicleMakeId: _selectedVehicleMakeId,
        vehicleModelId: _selectedVehicleModelId,
        plateNumber: _plateController.text,
        yearOfManufacture: int.tryParse(_yearController.text.trim()),
        seats: int.tryParse(_seatsController.text.trim()),
        fuelType: _fuelType,
        availability: _availability,
        licenseStatus: _licenseStatus,
        notes: _notesController.text,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Driver application saved. Continue with document upload.');
      await _reloadWorkspace();
    } on OnWayAuthException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _savingDraft = false);
      }
    }
  }

  Future<void> _saveDriverMode() async {
    setState(() => _updatingMode = true);
    try {
      await widget.authService!.updateDriverMode(
        isOnline: _driverOnline,
        serviceTypeIds: _selectedServiceIds.toList()..sort(),
      );
      if (!mounted) {
        return;
      }
      _showMessage(
        _driverOnline ? 'Driver mode is online.' : 'Driver mode paused.',
      );
      await _reloadWorkspace();
    } on OnWayAuthException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _updatingMode = false);
      }
    }
  }

  Future<void> _pickAndUploadDocument(
    OnWayDriverDocumentTypeOption documentType,
  ) async {
    setState(() => _uploadingDocumentType = documentType.value);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: true,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );

      final file = result?.files.singleOrNull;
      if (file == null) {
        return;
      }

      await widget.authService!.uploadDriverDocument(
        documentType: documentType.value,
        file: file,
      );

      if (!mounted) {
        return;
      }

      _showMessage('${documentType.label} uploaded and sent for review.');
      await _reloadWorkspace();
    } on OnWayAuthException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _uploadingDocumentType = null);
      }
    }
  }

  Future<void> _acceptRequest(DriverRequest request) async {
    final bookingId = request.id;
    if (bookingId == null) {
      _showMessage('This request is missing a booking identifier.');
      return;
    }

    setState(() => _requestActionBusy = true);
    try {
      await widget.authService!.acceptDriverRequest(bookingId);
      if (!mounted) {
        return;
      }
      _showMessage('Request accepted.');
      await _reloadWorkspace();
    } on OnWayAuthException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _requestActionBusy = false);
      }
    }
  }

  Future<void> _rejectRequest(DriverRequest request) async {
    final bookingId = request.id;
    if (bookingId == null) {
      _showMessage('This request is missing a booking identifier.');
      return;
    }

    setState(() => _requestActionBusy = true);
    try {
      await widget.authService!.rejectDriverRequest(bookingId);
      if (!mounted) {
        return;
      }
      _showMessage('Request rejected.');
      setState(() {
        _dispatchFuture = widget.authService!.fetchDriverRequests();
      });
    } on OnWayAuthException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _requestActionBusy = false);
      }
    }
  }

  Future<void> _openCounterOffer(DriverRequest request) async {
    final bookingId = request.id;
    if (bookingId == null) {
      _showMessage('This request is missing a booking identifier.');
      return;
    }

    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send counter-offer'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Counter amount (PKR)',
            hintText: 'Enter your offered amount',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(double.tryParse(controller.text.trim())),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (amount == null || amount <= 0) {
      return;
    }

    setState(() => _requestActionBusy = true);
    try {
      await widget.authService!.sendDriverCounterOffer(
        bookingId: bookingId,
        amount: amount,
      );
      if (!mounted) {
        return;
      }
      _showMessage('Counter-offer sent.');
      setState(() {
        _dispatchFuture = widget.authService!.fetchDriverRequests();
      });
    } on OnWayAuthException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _requestActionBusy = false);
      }
    }
  }

  Future<void> _advanceCurrentTrip(OnWayDriverCurrentTrip trip) async {
    final nextStatus = trip.nextPrimaryStatus;
    if (nextStatus == null) {
      setState(() {
        _dispatchFuture = widget.authService!.fetchDriverRequests();
      });
      return;
    }

    setState(() => _requestActionBusy = true);
    try {
      await widget.authService!.updateBookingStatus(
        bookingId: trip.id,
        status: nextStatus,
        note: 'Driver updated trip state from mobile driver mode.',
      );
      if (!mounted) {
        return;
      }
      _showMessage(trip.nextPrimaryActionLabel);
      await _reloadWorkspace();
    } on OnWayAuthException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _requestActionBusy = false);
      }
    }
  }

  Widget _currentTripCard(BuildContext context, OnWayDriverCurrentTrip trip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnWayTheme.slate,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Current rider: ${trip.riderName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                trip.fareLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(trip.serviceTitle),
          const SizedBox(height: 6),
          Text('${trip.pickup} -> ${trip.dropoff}'),
          const SizedBox(height: 6),
          Text(
            '${trip.statusLabel} | ${trip.paymentLabel}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _requestActionBusy
                      ? null
                      : () => _advanceCurrentTrip(trip),
                  child: Text(
                    _requestActionBusy
                        ? 'Updating...'
                        : trip.nextPrimaryActionLabel,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _requestActionBusy
                      ? null
                      : () async {
                          try {
                            await widget.authService!.updateBookingStatus(
                              bookingId: trip.id,
                              status: 'cancelled',
                              note: 'Driver cancelled from mobile mode.',
                              cancellationReason: 'Driver unavailable',
                            );
                            if (!mounted) {
                              return;
                            }
                            _showMessage('Trip cancelled.');
                            await _reloadWorkspace();
                          } on OnWayAuthException catch (error) {
                            _showMessage(error.message);
                          }
                        },
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _driverRequestCard(BuildContext context, DriverRequest request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnWayTheme.slate,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.serviceTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                request.fareLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${request.riderName} | ${request.paymentLabel}'),
          const SizedBox(height: 6),
          Text('${request.pickup} -> ${request.dropoff}'),
          const SizedBox(height: 6),
          Text(
            '${request.distanceLabel} | ${request.statusLine}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _requestActionBusy
                      ? null
                      : () => _acceptRequest(request),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _requestActionBusy
                      ? null
                      : () => _rejectRequest(request),
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
          if (request.canCounter) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _requestActionBusy
                  ? null
                  : () => _openCounterOffer(request),
              child: const Text('Send counter-offer'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _inlineStat(BuildContext context, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _statusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x29FFC107),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: OnWayTheme.yellow,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _progressTile(
    BuildContext context,
    String step,
    String label, {
    required bool complete,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: complete ? const Color(0x29FFC107) : Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: complete ? OnWayTheme.yellow : Colors.white54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }

  Widget _documentRow(
    BuildContext context,
    OnWayDriverDocumentTypeOption type,
    OnWayDriverDocumentSummary? document, {
    required bool uploadsLocked,
  }) {
    final help = document?.sampleHint ?? type.sampleHint ?? '';
    final uploading = _uploadingDocumentType == type.value;
    final statusColor = document == null
        ? Colors.white70
        : document.isApproved
        ? Colors.greenAccent.shade100
        : document.isRejected
        ? Colors.redAccent.shade100
        : OnWayTheme.yellow;
    final actionLabel = uploadsLocked
        ? 'Save profile first'
        : uploading
        ? 'Uploading...'
        : document == null
        ? 'Upload document'
        : document.canResubmit
        ? 'Replace document'
        : 'Upload again';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OnWayTheme.slate,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  type.label + (type.isRequired ? ' *' : ''),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                document?.effectiveStatusLabel ?? 'Not submitted',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: statusColor),
              ),
            ],
          ),
          if (help.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(help, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (document?.rejectionReason != null &&
              document!.rejectionReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: ${document.rejectionReason!}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.redAccent.shade100),
            ),
          ],
          if (document?.reviewedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Reviewed: ${document!.reviewedAt!}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (document?.submittedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Submitted: ${document!.submittedAt!}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: uploadsLocked || uploading
                  ? null
                  : () => _pickAndUploadDocument(type),
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }

  String _statusDescription(OnWayDriverApplication application) {
    switch (application.onboardingStatus) {
      case 'documents_pending':
        return 'Your profile is saved. Upload the remaining documents so review can continue.';
      case 'review':
        return 'Your application is under review. Watch this screen for approvals, rejections, and the next action.';
      case 'rejected':
        return 'Your application needs updates before approval. Review the flagged items and resubmit them.';
      case 'approved':
        return 'Your application is approved and you are ready to drive.';
      default:
        return 'Your application is being prepared for review.';
    }
  }

  String _stageHeadline(String stage) {
    switch (stage) {
      case 'vehicle':
        return 'Next step: add your main vehicle';
      case 'documents':
        return 'Next step: finish document upload';
      case 'review':
        return 'Next step: wait for review updates';
      case 'activation':
        return 'Next step: final activation';
      case 'approved':
        return 'You are ready to drive';
      default:
        return 'Next step: complete your profile';
    }
  }

  String _stageDescription(OnWayDriverApplication application) {
    final checklist = application.checklist;
    switch (checklist.stage) {
      case 'vehicle':
        return 'Your identity and service choices are saved. Add the vehicle you want to drive so document review stays linked to the right car or bike.';
      case 'documents':
        return checklist.requiredDocumentsRejected > 0
            ? 'One or more required documents were rejected. Replace them here and they will go back into review.'
            : 'Upload every required document. Each tile will show whether it is submitted, approved, or rejected.';
      case 'review':
        return 'All required documents are on file. This screen will keep showing review progress until final approval.';
      case 'activation':
        return 'All required documents are approved. The last step is final account activation from the operations team.';
      case 'approved':
        return 'Your setup is complete. Go online whenever you want to receive requests.';
      default:
        return 'Start with your city, identity details, and service choices. After that, continue into vehicle and document steps.';
    }
  }

  String _pretty(String value) {
    final normalized = value.replaceAll('_', ' ');
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DriverLoadingScreen extends StatelessWidget {
  const _DriverLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: OnWayPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: OnWayTheme.yellow),
              SizedBox(height: 16),
              Text('Loading driver tools...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverErrorScreen extends StatelessWidget {
  const _DriverErrorScreen({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: OnWayPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver mode is unavailable right now.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(message),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewDriverMode extends StatefulWidget {
  const _PreviewDriverMode({
    required this.stats,
    required this.requests,
    required this.services,
    required this.onOpenFleetOwner,
  });

  final List<DriverStat> stats;
  final List<DriverRequest> requests;
  final List<OnWayService> services;
  final VoidCallback onOpenFleetOwner;

  @override
  State<_PreviewDriverMode> createState() => _PreviewDriverModeState();
}

class _PreviewDriverModeState extends State<_PreviewDriverMode> {
  bool _online = true;
  late final Set<ServiceType> _enabledServices = {
    ServiceType.taxi,
    ServiceType.bikeTaxi,
    ServiceType.courier,
    ServiceType.cityToCity,
  };

  @override
  Widget build(BuildContext context) {
    final driverServices = widget.services.where((service) {
      return {
        ServiceType.taxi,
        ServiceType.bikeTaxi,
        ServiceType.rickshawTaxi,
        ServiceType.courier,
        ServiceType.cityToCity,
        ServiceType.schoolOffice,
      }.contains(service.type);
    }).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
        children: [
          BrandHeader(
            caption: 'Explore driving tools and trip requests',
            trailing: Switch(
              value: _online,
              activeThumbColor: OnWayTheme.yellow,
              onChanged: (value) => setState(() => _online = value),
            ),
          ),
          const SizedBox(height: 22),
          OnWayPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver workspace',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Review your earnings, request flow, and availability from one simple screen.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.onOpenFleetOwner,
                  child: const Text('Open business tools'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OnWayMapSurface(
            height: 240,
            interactive: false,
            markers: [
              const OnWayMapMarkerSpec(
                coordinate: OnWayMockData.driverLivePosition,
                icon: Icons.navigation_rounded,
                label: 'You',
                color: Color(0xFF91F2C0),
              ),
              ...widget.requests
                  .take(3)
                  .map(
                    (request) => OnWayMapMarkerSpec(
                      coordinate:
                          request.pickupCoordinate ??
                          OnWayMockData.coordinateForAddress(request.pickup),
                      icon: Icons.person_pin_circle_rounded,
                      label: request.serviceTitle,
                      size: 38,
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth > 760
                  ? (constraints.maxWidth - 48) / 4
                  : (constraints.maxWidth - 16) / 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final stat in widget.stats)
                    SizedBox(
                      width: width,
                      child: MetricTile(
                        label: stat.label,
                        value: stat.value,
                        delta: stat.delta,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final service in driverServices)
                FilterChip(
                  label: Text(service.title),
                  selected: _enabledServices.contains(service.type),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _enabledServices.add(service.type);
                      } else {
                        _enabledServices.remove(service.type);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          for (final request in widget.requests) ...[
            OnWayPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          request.serviceTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        request.fareLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${request.pickup} -> ${request.dropoff}'),
                  const SizedBox(height: 6),
                  Text(
                    '${request.distanceLabel} | ${request.paymentLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
