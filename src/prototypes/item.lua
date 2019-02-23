data:extend({
	{
		type = 'selection-tool',
		name = 'combinator-select-tool',
		stack_size = 1,
		order = 'a',
		flags = { 'hidden' },
		icon = '__controllinator__/graphics/item/combinator-select-tool.png',
		icon_size = 32,
		selection_color = { r = 0, g = 1, b = 0 },
		alt_selection_color = { r = 1, g = 0, b = 0 },
		selection_mode = { 'buildable-type', 'same-force' },
		alt_selection_mode = { 'buildable-type', 'same-force' },
		selection_cursor_box_type = 'entity',
		alt_selection_cursor_box_type = 'not-allowed',
		always_include_tiles = false
	}
})
