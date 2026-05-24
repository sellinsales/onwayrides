import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../auth/onway_auth_service.dart';
import '../auth/onway_auth_session.dart';
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

  final _licenseController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _plateController = TextEditingController();
  final _yearController = TextEditingController();
  final _seatsController = TextEditingController();
  final _notesController = TextEditingController();

  bool _editingApplication = false;
  bool _formHydrated = false;
  bool _savingDraft = false;
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
      _workspaceFuture = widget.authService!.fetchDriverWorkspace();
    }
  }

  @override
  void dispose() {
    _dispatchTimer?.cancel();
    _licenseController.dispose();
    _nationalIdController.dispose();
    _plateController.dispose();
    _yearController.dispose();
    _seatsController.dispose();
    _notesController.dispose();
    super.dispose();
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
                caption: 'One account for rider trips and driver growth',
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
        ? 'Rider mode active'
        : application.isApproved
        ? 'Driver mode approved'
        : application.statusLabel;
    final title = application == null
        ? 'Drive with the same OnWay account'
        : application.isApproved
        ? 'You can switch between rider and driver in one app'
        : 'Your driver journey is in progress';
    final description = application == null
        ? 'Apply as a driver without creating a second app account. Keep your rider history, profile and support links in the same place.'
        : application.isApproved
        ? 'Go online when you want work, stay in rider mode when you just need a booking, and keep one identity across both sides of the platform.'
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
                label: application?.isApproved == true
                    ? 'Driver live'
                    : 'Driver path',
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
                'Driver code',
              ),
              _inlineStat(
                context,
                '${application?.documents.length ?? 0}',
                'Documents on file',
              ),
              _inlineStat(
                context,
                '${_selectedServiceIds.length}',
                'Enabled services',
              ),
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

    return [
      SectionHeading(
        title: application == null
            ? 'Become a driver'
            : 'Continue driver application',
        subtitle: application == null
            ? 'Use a guided, market-style onboarding flow: identity, services, vehicle, then document review.'
            : 'Keep your driver draft updated while review and document approval move in parallel.',
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
              application == null
                  ? 'One app, two earning paths'
                  : 'Application status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              application == null
                  ? 'You can keep booking rides as a rider while building your driver profile. This is the main difference in the OnWay approach: no separate driver app is required during onboarding.'
                  : _statusDescription(application),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _statusBadge(application?.statusLabel ?? 'Not started'),
                if (application != null)
                  _statusBadge(
                    '${application.documents.length} documents uploaded',
                  ),
                _statusBadge('Support review during beta'),
              ],
            ),
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
        title: 'Driver operations',
        subtitle:
            'This follows the same pattern as market apps: go online, choose what you want to accept, then wait for nearby demand.',
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
              'Dispatch rollout',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 10),
            Text(
              'Rider booking is already live in this shared app. Live nearby driver requests, counter-offers, and streaming dispatch are the next operational layer.',
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
                    ? 'Polling nearby requests every few seconds. This is the operational beta path before full realtime sockets.'
                    : 'Go online first to start receiving nearby rider demand.',
              ),
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
    final existingByType = {
      for (final document
          in bundle.driverApplication?.documents ??
              const <OnWayDriverDocumentSummary>[])
        document.documentType: document,
    };

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
            'Keep this part light during beta. Save your core driver profile here, then complete secure document review as support activates mobile uploads.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (final type in bundle.documentTypes.take(4)) ...[
            _documentRow(
              context,
              type,
              existingByType[type.value]?.status ?? 'needed',
              bundle.driverSamples[type.value] ?? '',
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

      _showMessage('Driver draft saved.');
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

      _showMessage('${documentType.label} uploaded.');
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

  Widget _documentRow(
    BuildContext context,
    OnWayDriverDocumentTypeOption type,
    String status,
    String help,
  ) {
    final uploading = _uploadingDocumentType == type.value;
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
                  type.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                _pretty(status),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: status == 'approved'
                      ? Colors.greenAccent.shade100
                      : OnWayTheme.yellow,
                ),
              ),
            ],
          ),
          if (help.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(help, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: uploading ? null : () => _pickAndUploadDocument(type),
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(uploading ? 'Uploading...' : 'Upload document'),
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
        return 'Your basic driver profile is saved. Keep your city, services and vehicle details current while documents are reviewed.';
      case 'review':
        return 'Your application is in review. Support can verify your setup without forcing you into a separate app.';
      case 'rejected':
        return 'Your application needs updates before approval. Correct the draft below and resubmit.';
      default:
        return 'Your application is being prepared for review.';
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
              Text('Loading driver workspace...'),
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
            caption: 'Preview driver mode with requests and operations',
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
                  'Preview-only driver mode',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'This preview mirrors the final live layout once driver approval and dispatch are active in the backend.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.onOpenFleetOwner,
                  child: const Text('Open Fleet Owner module'),
                ),
              ],
            ),
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
