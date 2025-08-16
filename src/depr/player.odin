package game

Player :: struct {
	state:    PlayerState,
	position: Vec3,
}

PlayerState :: union {
	PlayerStateIdle,
	PlayerStateIdleLong,
	PlayerStateWalking,
	PlayerStateRunning,
	// PlayerStateCrouching,
	// PlayerStateJumping,
	// PlayerStateAir,
	// PlayerStateFalling,
	// PlayerStateHang,
	// PlayerStateHangClimb,
	// PlayerStateHangSlide,
}

PlayerStateIdle :: struct {}
PlayerStateIdleLong :: struct {}
PlayerStateWalking :: struct {}
PlayerStateRunning :: struct {}
// PlayerStateCrouching :: struct {}
// PlayerStateJumping :: struct {}
// PlayerStateAir :: struct {}
// PlayerStateFalling :: struct {}
// PlayerStateHang :: struct {}
// PlayerStateHangClimb :: struct {}
// PlayerStateHangSlide :: struct {}

