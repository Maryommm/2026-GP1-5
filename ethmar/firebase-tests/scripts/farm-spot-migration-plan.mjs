export const MAX_LANDS = 9;
export const SQUARES_PER_LAND = 25;

export function spotId(land, square) {
  if (
    !Number.isInteger(land) ||
    !Number.isInteger(square) ||
    land < 0 ||
    land >= MAX_LANDS ||
    square < 0 ||
    square >= SQUARES_PER_LAND
  ) {
    throw new RangeError(`Invalid farm spot (${land}, ${square})`);
  }
  return `l${land}s${square}`;
}

export function planFarmSpots(plants) {
  const groups = new Map();
  const invalid = [];

  for (const plant of plants) {
    const { id, data } = plant;
    const land = data.land;
    const square = data.square;
    if (
      typeof id !== 'string' ||
      id.length === 0 ||
      !Number.isInteger(land) ||
      !Number.isInteger(square) ||
      land < 0 ||
      land >= MAX_LANDS ||
      square < 0 ||
      square >= SQUARES_PER_LAND
    ) {
      invalid.push(id);
      continue;
    }

    const key = spotId(land, square);
    const group = groups.get(key) ?? { land, square, plantIds: [] };
    group.plantIds.push(id);
    groups.set(key, group);
  }

  const desired = new Map();
  const conflicts = [];
  for (const [id, group] of groups) {
    group.plantIds.sort();
    if (group.plantIds.length === 1) {
      desired.set(id, {
        status: 'reserved',
        plantId: group.plantIds[0],
        land: group.land,
        square: group.square,
      });
    } else {
      const record = {
        status: 'conflict',
        plantIds: group.plantIds,
        land: group.land,
        square: group.square,
      };
      desired.set(id, record);
      conflicts.push({ spotId: id, ...record });
    }
  }

  return { desired, conflicts, invalid };
}

export function samePlacement(existing, desired) {
  const expectedKeys =
    desired.status === 'reserved'
      ? ['createdAt', 'land', 'plantId', 'square', 'status']
      : ['createdAt', 'land', 'plantIds', 'square', 'status'];
  const actualKeys =
    existing && typeof existing === 'object' ? Object.keys(existing).sort() : [];
  if (
    actualKeys.join('\0') !== expectedKeys.join('\0') ||
    typeof existing.createdAt?.toMillis !== 'function' ||
    !Number.isFinite(existing.createdAt.toMillis()) ||
    existing?.status !== desired.status ||
    existing?.land !== desired.land ||
    existing?.square !== desired.square
  ) {
    return false;
  }
  if (desired.status === 'reserved') {
    return existing.plantId === desired.plantId;
  }
  return (
    Array.isArray(existing.plantIds) &&
    [...existing.plantIds].sort().join('\0') ===
      [...desired.plantIds].sort().join('\0')
  );
}
