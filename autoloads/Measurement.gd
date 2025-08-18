extends Node

const PX_PER_INCH: float = 40.0
const MM_PER_INCH: float = 25.4

func inches_to_px(inches: float) -> float:
	return inches * PX_PER_INCH

func px_to_inches(pixels: float) -> float:
	return pixels / PX_PER_INCH

func mm_to_px(mm: float) -> float:
	var inches = mm / MM_PER_INCH
	return inches_to_px(inches)

func px_to_mm(pixels: float) -> float:
	var inches = px_to_inches(pixels)
	return inches * MM_PER_INCH

func base_radius_px(base_mm: int) -> float:
	return mm_to_px(base_mm) / 2.0

func distance_inches(pos1: Vector2, pos2: Vector2) -> float:
	var dist_px = pos1.distance_to(pos2)
	return px_to_inches(dist_px)

func distance_px(pos1: Vector2, pos2: Vector2) -> float:
	return pos1.distance_to(pos2)