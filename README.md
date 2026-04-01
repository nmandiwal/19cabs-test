# 19Cabs E2E Tests

Automated end-to-end regression tests for the 19Cabs customer and driver apps using [Maestro](https://maestro.mobile.dev/).

## Pre-requisites

- **Mac Mini** with backend running on `localhost:3001` and pricing on `localhost:3002`
- **Android emulator** running OR physical device connected via USB
- **Maestro CLI** installed: `brew install maestro`
- **ADB** installed (comes with Android SDK)
- Customer app (`com.nineteencabs.mobileapp`) installed on device
- Driver app (`com.nineteencabs.driver`) installed on device

## Setup

```bash
cd 19cabs-test
cp .env.example .env
# Edit .env with your Firebase credentials and device serial
npm install
chmod +x run.sh
```

## Run tests

```bash
# Run full test suite
./run.sh

# Run a single flow
maestro test maestro/flows/customer/customer_login.yaml
```

## Structure

```
19cabs-test/
├── maestro/
│   ├── flows/
│   │   ├── customer/       # Customer app flows
│   │   └── driver/         # Driver app flows (TODO)
│   └── suites/             # Multi-flow test suites (TODO)
├── scripts/                # DB seed/cleanup/verify scripts (TODO)
├── run.sh                  # Main orchestrator
├── .env                    # Credentials (gitignored)
└── package.json
```

## Test accounts

| Phone | OTP | Role | Notes |
|---|---|---|---|
| 9999999993 | 1234 | Customer | Dev test account |

## Location

Tests default to **Milton Keynes Central** (52.0349, -0.7744). For emulators, location is set automatically via `adb emu geo fix`. For physical devices, use a mock location app.
