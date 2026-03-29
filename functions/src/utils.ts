export interface ReadingLike {
  heartRate?: number;
  respiratoryRate?: number;
  pulseRate?: number;
  breathingRate?: number;
  stressLevel?: number;
}

export function getStressLevel(reading: ReadingLike): number {
  if (typeof reading.stressLevel === "number") {
    return reading.stressLevel;
  }

  const pulseRate = reading.pulseRate ?? reading.heartRate ?? 0;
  const breathingRate = reading.breathingRate ?? reading.respiratoryRate ?? 0;
  const pulseStress = Math.max(0, Math.min(100, ((pulseRate - 60) / 40) * 50));
  const breathingStress = Math.max(0, Math.min(100, ((breathingRate - 12) / 8) * 50));
  return Math.min(100, pulseStress + breathingStress);
}

export function getPulseRate(reading: ReadingLike): number | null {
  return reading.pulseRate ?? reading.heartRate ?? null;
}

export function getBreathingRate(reading: ReadingLike): number | null {
  return reading.breathingRate ?? reading.respiratoryRate ?? null;
}

export function toDateStr(date: Date): string {
  return date.toISOString().split("T")[0];
}

export function makeFriendshipID(uidA: string, uidB: string): string {
  return uidA < uidB ? `${uidA}_${uidB}` : `${uidB}_${uidA}`;
}
