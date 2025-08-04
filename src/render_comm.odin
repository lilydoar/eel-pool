package shared

import "core:sync"
import "core:log"

RenderPacketType :: enum {
	GOL_BOARD,
}

GOLBoardRenderPacket :: struct {
	board_size: i32,
	board_data: [dynamic]i32,
}

RenderPacket :: struct {
	type: RenderPacketType,
	data: union {
		GOLBoardRenderPacket,
	},
}

RenderBuffer :: struct {
	buffers:       [2]RenderPacket,
	write_index:   i32,
	read_index:    i32,
	mutex:         sync.Mutex,
	has_new_data:  bool,
}

render_buffer: RenderBuffer

render_packet_deinit :: proc(packet: ^RenderPacket) {
	switch &variant in packet.data {
	case GOLBoardRenderPacket:
		delete(variant.board_data)
	}
}

render_packet_clone :: proc(src: ^RenderPacket) -> RenderPacket {
	dst := RenderPacket{
		type = src.type,
	}
	
	switch &src_variant in src.data {
	case GOLBoardRenderPacket:
		dst_variant := GOLBoardRenderPacket{
			board_size = src_variant.board_size,
			board_data = make([dynamic]i32, len(src_variant.board_data)),
		}
		copy_slice(dst_variant.board_data[:], src_variant.board_data[:])
		dst.data = dst_variant
	}
	
	return dst
}

render_buffer_init :: proc() {
	render_buffer.write_index = 0
	render_buffer.read_index = 1
	render_buffer.has_new_data = false
}

render_buffer_deinit :: proc() {
	sync.lock(&render_buffer.mutex)
	defer sync.unlock(&render_buffer.mutex)
	
	render_packet_deinit(&render_buffer.buffers[0])
	render_packet_deinit(&render_buffer.buffers[1])
}

render_buffer_write :: proc(packet: ^RenderPacket) {
	sync.lock(&render_buffer.mutex)
	defer sync.unlock(&render_buffer.mutex)
	
	// Debug: Log when we write a packet
	log.debug("Render buffer: writing new packet")
	
	// Clean up existing data in write buffer
	render_packet_deinit(&render_buffer.buffers[render_buffer.write_index])
	
	// Clone new packet data into write buffer
	render_buffer.buffers[render_buffer.write_index] = render_packet_clone(packet)
	
	// Mark that new data is available for reading
	render_buffer.has_new_data = true
}

render_buffer_read :: proc() -> (packet: ^RenderPacket, has_data: bool) {
	sync.lock(&render_buffer.mutex)
	defer sync.unlock(&render_buffer.mutex)
	
	if !render_buffer.has_new_data {
		return nil, false
	}
	
	// Debug: Log when we successfully read a packet
	log.debug("Render buffer: reading packet with new data")
	
	// Swap buffers so reader gets the newly written data
	render_buffer.write_index, render_buffer.read_index = render_buffer.read_index, render_buffer.write_index
	render_buffer.has_new_data = false
	
	return &render_buffer.buffers[render_buffer.read_index], true
}