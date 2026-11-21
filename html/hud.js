const hud = document.getElementById('hud');
const lampRow = document.getElementById('lamp-row');
const speed = document.getElementById('speed');
const speedUnitLabel = document.getElementById('speed-unit');
const analogScale = document.getElementById('analog-scale');
const fuelValue = document.getElementById('fuel-value');
const fuelCaption = document.getElementById('fuel-caption');
const fuelBar = document.getElementById('fuel-bar');
const fuelDial = document.getElementById('fuel-dial');
const rpmStrip = document.getElementById('rpm-strip');
const gearValue = document.getElementById('gear-value');
const leftSignal = document.getElementById('left-signal');
const rightSignal = document.getElementById('right-signal');
const checkEngine = document.getElementById('check-engine');
const fuelWarning = document.getElementById('fuel-warning');
const seatbeltWarning = document.getElementById('seatbelt-warning');
const seatbeltSound = document.getElementById('seatbelt-sound');
const headlights = document.getElementById('headlights');
const cruiseLamp = document.getElementById('cruise-control');
const siren = document.getElementById('siren');
const rpmSegments = 12;
const speedScales = {
    kmh: { label: 'km/h', max: 240, tick: 10, majorTick: 40 },
    mph: { label: 'mph', max: 150, tick: 5, majorTick: 25 }
};
const speedRingThemes = new Set(['single_round', 'dual_round', 'electric', 'touring', 'orbit']);
const translations = {
    de: {
        dashboard: 'Fahrzeuganzeige',
        lamps: 'Kontrollleuchten',
        leftSignal: 'Blinker links',
        rightSignal: 'Blinker rechts',
        checkEngine: 'Motorkontrolle',
        fuelWarning: 'Tankreserve',
        batteryWarning: 'Niedriger Akkustand',
        seatbelt: 'Sicherheitsgurt',
        cruise: 'Tempomat',
        fuel: 'Tank',
        battery: 'Akku',
        gear: 'Gang',
        rpm: 'U/min',
        rpmMeter: 'Relative Motordrehzahl',
        altitude: 'Höhe über Grund',
        verticalSpeed: 'Vertikal',
        heading: 'Kurs',
        landingGear: 'Fahrwerk',
        landingGearStates: { 0: 'Ausgefahren', 1: 'Fährt ein', 3: 'Fährt aus', 4: 'Eingefahren', 5: 'Defekt' },
        sirenOn: 'Sirene aktiv',
        sirenOff: 'Sirene aus',
        highBeam: 'Fernlicht',
        lowBeam: 'Abblendlicht',
        lightsOff: 'Licht aus'
    },
    en: {
        dashboard: 'Vehicle dashboard',
        lamps: 'Indicator lights',
        leftSignal: 'Left turn signal',
        rightSignal: 'Right turn signal',
        checkEngine: 'Check engine',
        fuelWarning: 'Low fuel',
        batteryWarning: 'Low battery',
        seatbelt: 'Seat belt',
        cruise: 'Cruise control',
        fuel: 'Fuel',
        battery: 'Battery',
        gear: 'Gear',
        rpm: 'RPM',
        rpmMeter: 'Relative engine speed',
        altitude: 'Height above ground',
        verticalSpeed: 'Vertical speed',
        heading: 'Heading',
        landingGear: 'Landing gear',
        landingGearStates: { 0: 'Down', 1: 'Retracting', 3: 'Extending', 4: 'Up', 5: 'Damaged' },
        sirenOn: 'Siren on',
        sirenOff: 'Siren off',
        highBeam: 'High beam',
        lowBeam: 'Low beam',
        lightsOff: 'Lights off'
    }
};
let currentLocale;
let hudAudio;
let seatbeltChimeTimer;
let fuelWarningTone;
let fuelWarningTimer;
let indicatorVolume = 0;
let indicatorTimer;
let indicatorsLit = false;
const colorProperties = {
    accent: '--hud-accent',
    speed: '--hud-speed',
    rpm: '--hud-rpm',
    fuel: '--hud-fuel',
    redline: '--hud-redline',
    reserve: '--hud-reserve',
    text: '--hud-text',
    muted: '--hud-muted',
    track: '--hud-track',
    ticks: '--hud-ticks',
    border: '--hud-border',
    dialCenter: '--hud-dial-center',
    dialEdge: '--hud-dial-edge',
    panel: '--hud-panel',
    background: '--hud-background',
    backgroundEdge: '--hud-background-edge',
    needle: '--hud-needle',
    gear: '--hud-gear'
};
const hexColor = /^#(?:[\da-f]{6}|[\da-f]{8})$/i;

function applyTheme(theme, colors) {
    if (hud.dataset.theme === theme) {
        return;
    }

    hud.dataset.theme = theme;
    for (const [key, property] of Object.entries(colorProperties)) {
        const color = colors?.[key];
        if (typeof color === 'string' && hexColor.test(color)) {
            hud.style.setProperty(property, color);
        } else {
            hud.style.removeProperty(property);
        }
    }
}

function setLampLabel(lamp, label) {
    lamp.title = label;
    lamp.setAttribute('aria-label', label);
}

function getHudAudio() {
    if (!window.AudioContext) {
        return;
    }

    hudAudio ??= new window.AudioContext();
    if (hudAudio.state !== 'running') {
        void hudAudio.resume().catch(() => {});
        return;
    }
    return hudAudio;
}

function playIndicatorClick() {
    const audio = indicatorVolume > 0 ? getHudAudio() : null;
    if (!audio) {
        return;
    }

    const start = audio.currentTime;
    const oscillator = audio.createOscillator();
    const gain = audio.createGain();
    oscillator.type = 'triangle';
    oscillator.frequency.setValueAtTime(indicatorsLit ? 850 : 610, start);
    oscillator.frequency.exponentialRampToValueAtTime(230, start + 0.032);
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(Math.max(0.0001, indicatorVolume * 0.14), start + 0.003);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.04);
    oscillator.connect(gain);
    gain.connect(audio.destination);
    oscillator.onended = () => {
        oscillator.disconnect();
        gain.disconnect();
    };
    oscillator.start(start);
    oscillator.stop(start + 0.045);
}

function stopFuelWarning() {
    if (fuelWarningTimer !== undefined) {
        window.clearTimeout(fuelWarningTimer);
        fuelWarningTimer = undefined;
    }
    if (fuelWarningTone) {
        fuelWarningTone.stop();
        fuelWarningTone = undefined;
    }
}

function playFuelWarningPulse(volume, duration) {
    const audio = getHudAudio();
    if (!audio) {
        return;
    }

    const start = audio.currentTime;
    const end = start + duration;
    const tone = audio.createOscillator();
    const gain = audio.createGain();
    tone.frequency.setValueAtTime(740, start);
    gain.gain.setValueAtTime(0.0001, start);
    const peak = Math.max(0.0001, volume * 0.2);
    gain.gain.linearRampToValueAtTime(peak, start + Math.min(0.012, duration / 4));
    gain.gain.setValueAtTime(peak, end - Math.min(0.07, duration / 2));
    gain.gain.exponentialRampToValueAtTime(0.0001, end);
    tone.connect(gain);
    gain.connect(audio.destination);
    tone.onended = () => {
        tone.disconnect();
        gain.disconnect();
        if (fuelWarningTone === tone) {
            fuelWarningTone = undefined;
        }
    };
    fuelWarningTone = tone;
    tone.start(start);
    tone.stop(end);
}

function startFuelWarning(volume, seconds, intervalSeconds) {
    stopFuelWarning();
    if (volume <= 0 || seconds <= 0) {
        return;
    }

    const deadline = performance.now() + seconds * 1000;
    const interval = Math.max(250, intervalSeconds * 1000);
    const pulse = () => {
        fuelWarningTimer = undefined;
        const remaining = deadline - performance.now();
        if (remaining <= 0) {
            return;
        }

        playFuelWarningPulse(volume, Math.min(0.21, remaining / 1000));
        if (remaining > interval) {
            fuelWarningTimer = window.setTimeout(pulse, interval);
        }
    };
    pulse();
}

function stopSeatbeltChime() {
    if (seatbeltChimeTimer !== undefined) {
        window.clearTimeout(seatbeltChimeTimer);
        seatbeltChimeTimer = undefined;
        seatbeltSound.pause();
    }
}

function playSeatbeltChime(volume, duration) {
    if (volume <= 0 || duration <= 0) {
        return;
    }

    stopSeatbeltChime();
    seatbeltSound.currentTime = 0;
    seatbeltSound.volume = volume;
    const timer = window.setTimeout(stopSeatbeltChime, duration);
    seatbeltChimeTimer = timer;
    void seatbeltSound.play().catch(() => {
        if (seatbeltChimeTimer === timer) {
            stopSeatbeltChime();
        }
    });
}

function tickIndicators() {
    indicatorsLit = !indicatorsLit;
    lampRow.classList.toggle('signals-dim', !indicatorsLit);
    playIndicatorClick();
}

function updateIndicatorBlink(active) {
    if (active) {
        if (indicatorTimer === undefined) {
            tickIndicators();
            indicatorTimer = window.setInterval(tickIndicators, 400);
        }
    } else if (indicatorTimer !== undefined) {
        window.clearInterval(indicatorTimer);
        indicatorTimer = undefined;
        indicatorsLit = false;
        lampRow.classList.remove('signals-dim');
    }
}

function applyLocale(locale, labels) {
    if (currentLocale === locale) {
        return;
    }
    currentLocale = locale;
    document.documentElement.lang = locale;
    hud.setAttribute('aria-label', labels.dashboard);
    lampRow.setAttribute('aria-label', labels.lamps);
    setLampLabel(leftSignal, labels.leftSignal);
    setLampLabel(rightSignal, labels.rightSignal);
    setLampLabel(checkEngine, labels.checkEngine);
    setLampLabel(seatbeltWarning, labels.seatbelt);
    document.getElementById('gear-caption').textContent = labels.gear;
    document.getElementById('rpm-caption').textContent = labels.rpm;
    rpmStrip.setAttribute('aria-label', labels.rpmMeter);
    document.getElementById('altitude-caption').textContent = labels.altitude;
    document.getElementById('vertical-speed-caption').textContent = labels.verticalSpeed;
    document.getElementById('heading-caption').textContent = labels.heading;
    document.getElementById('landing-gear-caption').textContent = labels.landingGear;
}

function drawAnalogScale({ max, tick, majorTick }) {
    analogScale.replaceChildren();
    for (let value = 0; value <= max; value += tick) {
        const mark = document.createElement('span');
        const angle = (value / max * 270 - 135) * Math.PI / 180;
        const major = value % majorTick === 0;
        mark.className = major ? 'analog-mark major' : 'analog-mark';
        mark.style.transform = `rotate(${angle}rad)`;
        analogScale.append(mark);

        if (major) {
            const label = document.createElement('span');
            label.className = 'analog-number';
            label.textContent = value;
            label.style.left = `${50 + Math.sin(angle) * 34}%`;
            label.style.top = `${50 - Math.cos(angle) * 34}%`;
            analogScale.append(label);
        }
    }
}

window.addEventListener('message', ({ data }) => {
    if (data?.action !== 'vehicleHud') {
        return;
    }

    hud.hidden = !data.visible;
    if (hud.hidden) {
        updateIndicatorBlink(false);
        stopSeatbeltChime();
        stopFuelWarning();
        return;
    }

    const locale = data.locale === 'en' ? 'en' : 'de';
    const labels = translations[locale];
    applyLocale(locale, labels);
    applyTheme(data.theme ?? 'arcane', data.colors);
    const analogTheme = data.theme === 'analog' || data.theme === 'vintage';
    const speedUnit = data.speedUnit === 'mph' ? 'mph' : 'kmh';
    const speedScale = speedScales[speedUnit];
    speedUnitLabel.textContent = speedScale.label;
    speed.textContent = String(data.speed).padStart(data.theme === 'bicycle' ? 1 : 3, '0');
    const flightTheme = data.theme === 'aircraft' || data.theme === 'fighter_jet';
    if (flightTheme) {
        document.getElementById('altitude-value').textContent = Number.isFinite(data.altitude)
            ? `${Math.round(data.altitude)} m` : '—';
        const verticalSpeed = Number.isFinite(data.verticalSpeed) ? data.verticalSpeed.toFixed(1) : null;
        document.getElementById('vertical-speed-value').textContent = verticalSpeed !== null
            ? `${locale === 'de' ? verticalSpeed.replace('.', ',') : verticalSpeed} m/s` : '—';
        document.getElementById('heading-value').textContent = Number.isFinite(data.heading)
            ? `${String(Math.round(data.heading) % 360).padStart(3, '0')}°` : '—';
        const landingGear = document.getElementById('landing-gear-value');
        landingGear.textContent = labels.landingGearStates[data.landingGear] ?? '—';
        landingGear.dataset.state = data.landingGear ?? '';
    }
    if (analogTheme || speedRingThemes.has(data.theme)) {
        const sweep = Math.min(1, Math.max(0, data.speed / speedScale.max)) * 270;
        if (analogTheme) {
            if (analogScale.dataset.unit !== speedUnit) {
                drawAnalogScale(speedScale);
                analogScale.dataset.unit = speedUnit;
            }
            hud.style.setProperty('--analog-angle', `${sweep - 135}deg`);
        } else {
            hud.style.setProperty('--dial-sweep', `${sweep}deg`);
        }
    }
    const gear = data.gear;
    gearValue.textContent = gear === 0 ? 'R' : Number.isInteger(gear) && gear > 0 ? gear : '—';
    const rpm = Math.min(1, Math.max(0, data.rpm ?? 0));
    const litSegments = Math.ceil(rpm * rpmSegments);
    rpmStrip.style.setProperty('--rpm-fill', `${litSegments / rpmSegments * 100}%`);
    if (data.theme === 'supercar2') {
        rpmStrip.style.setProperty('--cockpit-sweep', `${rpm * 140}deg`);
    }
    if (data.theme === 'supercar3') {
        rpmStrip.style.setProperty('--cluster-sweep', `${rpm * 270}deg`);
    }
    rpmStrip.setAttribute('aria-valuenow', Math.round(rpm * 100));
    const hasFuel = Number.isFinite(data.fuel);
    const lowFuel = hasFuel && data.fuel < 15;
    const engineWarning = data.checkEngine === true;
    lampRow.hidden = data.bicycle === true || data.theme === 'bicycle'
        || (flightTheme && !engineWarning && !lowFuel);
    const cruiseActive = Number.isFinite(data.cruiseSpeed) && !lampRow.hidden && !flightTheme;
    cruiseLamp.hidden = !cruiseActive;
    cruiseLamp.classList.toggle('active', cruiseActive);
    if (cruiseActive) {
        setLampLabel(cruiseLamp, `${labels.cruise} ${data.cruiseSpeed} ${speedScale.label}`);
    }
    if (data.theme === 'orbit') {
        rpmStrip.style.setProperty('--orbit-rpm-sweep', `${rpm * 200}deg`);
        fuelDial.style.setProperty('--orbit-fuel-sweep', `${hasFuel ? data.fuel * 1.8 : 0}deg`);
    }
    if (analogTheme) {
        rpmStrip.style.setProperty('--analog-gauge-angle', `${rpm * 130 - 65}deg`);
        if (hasFuel) {
            const fraction = Math.min(1, Math.max(0, data.fuel / 100));
            fuelDial.style.setProperty('--analog-gauge-angle', `${fraction * 130 - 65}deg`);
        }
    }
    if ((data.theme === 'electric' || data.theme === 'touring') && hasFuel) {
        fuelDial.style.setProperty('--fuel-level', `${data.fuel}%`);
    }
    if (data.theme === 'dual_round') {
        rpmStrip.style.setProperty('--rpm-sweep', `${rpm * 270}deg`);
        const fuelFraction = hasFuel ? Math.min(1, Math.max(0, data.fuel / 100)) : 0;
        fuelDial.style.setProperty('--fuel-sweep', `${fuelFraction * 270}deg`);
    }
    fuelValue.textContent = hasFuel ? `${Math.floor(data.fuel)} %` : '—';
    const electricVehicle = data.theme === 'electric' && data.electric === true;
    fuelCaption.textContent = electricVehicle ? labels.battery : labels.fuel;
    setLampLabel(fuelWarning, electricVehicle ? labels.batteryWarning : labels.fuelWarning);
    fuelBar.hidden = !hasFuel;
    fuelBar.classList.toggle('low', lowFuel);
    if (hasFuel) {
        fuelBar.value = data.fuel;
    }

    const leftActive = data.leftSignal === true;
    const rightActive = data.rightSignal === true;
    leftSignal.classList.toggle('active', leftActive);
    rightSignal.classList.toggle('active', rightActive);
    indicatorVolume = Number.isFinite(data.indicatorSoundVolume)
        ? Math.min(1, Math.max(0, data.indicatorSoundVolume)) : 0;
    updateIndicatorBlink(!lampRow.hidden && !flightTheme && (leftActive || rightActive));
    checkEngine.classList.toggle('active', engineWarning);
    fuelWarning.classList.toggle('active', lowFuel);
    if (!lowFuel || lampRow.hidden) {
        stopFuelWarning();
    } else if (Number.isFinite(data.fuelWarningChimeVolume)) {
        startFuelWarning(
            Math.min(1, Math.max(0, data.fuelWarningChimeVolume)),
            Number.isFinite(data.fuelWarningSoundSeconds) ? data.fuelWarningSoundSeconds : 5,
            Number.isFinite(data.fuelWarningIntervalSeconds) ? data.fuelWarningIntervalSeconds : 0.8
        );
    }
    seatbeltWarning.classList.toggle('active', data.seatbeltWarning === true);
    seatbeltWarning.hidden = data.theme === 'motorcycle' && data.seatbeltAvailable === false;
    if (data.seatbeltWarning !== true || lampRow.hidden || flightTheme || seatbeltWarning.hidden) {
        stopSeatbeltChime();
    } else if (Number.isFinite(data.seatbeltChimeVolume) && Number.isFinite(data.seatbeltChimeMs)) {
        playSeatbeltChime(Math.min(1, Math.max(0, data.seatbeltChimeVolume)), data.seatbeltChimeMs);
    }
    const sirenActive = data.siren === true;
    siren.hidden = data.hasSiren !== true && !sirenActive;
    siren.classList.toggle('active', sirenActive);
    siren.setAttribute('aria-label', sirenActive ? labels.sirenOn : labels.sirenOff);
    if (data.highBeam === true) {
        headlights.dataset.beam = 'high';
        headlights.setAttribute('aria-label', labels.highBeam);
    } else if (data.lowBeam === true) {
        headlights.dataset.beam = 'low';
        headlights.setAttribute('aria-label', labels.lowBeam);
    } else {
        headlights.dataset.beam = 'off';
        headlights.setAttribute('aria-label', labels.lightsOff);
    }
});
