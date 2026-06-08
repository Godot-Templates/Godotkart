class_name InventoryScreen
extends Control

const SLOT_SIZE = 58.0
const SLOT_GAP = 8.0
const PANEL_PADDING = 24.0
const WINDOW_SIZE = Vector2(760.0, 570.0)
const MAIN_SLOT_COUNT = 27
const ARMOR_SLOT_COUNT = 4
const CRAFT_SLOT_COUNT = 4
const MAX_STACK_SIZE = 64

const GROUP_MAIN = "main"
const GROUP_ARMOR = "armor"
const GROUP_CRAFT = "craft"
const GROUP_OUTPUT = "output"

const ITEM_LOG = "wood_log"
const ITEM_PLANKS = "wood_planks"

const BACKDROP_COLOR = Color(0.02, 0.02, 0.025, 0.76)
const PANEL_COLOR = Color(0.18, 0.18, 0.19, 1.0)
const PANEL_BORDER_COLOR = Color(0.42, 0.42, 0.44, 1.0)
const SLOT_COLOR = Color(0.32, 0.32, 0.34, 1.0)
const SLOT_HOVER_COLOR = Color(0.52, 0.52, 0.54, 1.0)
const SLOT_BORDER_COLOR = Color(0.08, 0.08, 0.09, 1.0)
const TEXT_COLOR = Color(0.88, 0.88, 0.86, 1.0)
const MUTED_TEXT_COLOR = Color(0.64, 0.64, 0.64, 1.0)

class ItemStack:
    var item_id: String = ""
    var count: int = 0

    func _init(p_item_id: String = "", p_count: int = 0) -> void:
        item_id = p_item_id
        count = p_count
        if count <= 0:
            clear()

    func is_empty() -> bool:
        return item_id == "" or count <= 0

    func set_item(p_item_id: String, p_count: int) -> void:
        item_id = p_item_id
        count = p_count
        if count <= 0:
            clear()

    func clear() -> void:
        item_id = ""
        count = 0

    func copy_from(other: ItemStack) -> void:
        item_id = other.item_id
        count = other.count
        if count <= 0:
            clear()

    func duplicate_stack() -> ItemStack:
        return ItemStack.new(item_id, count)


class SlotRef:
    var group: String = ""
    var index: int = -1
    var rect: Rect2 = Rect2()

    func _init(p_group: String, p_index: int, p_rect: Rect2) -> void:
        group = p_group
        index = p_index
        rect = p_rect


var _main_slots: Array[ItemStack] = []
var _armor_slots: Array[ItemStack] = []
var _craft_slots: Array[ItemStack] = []
var _held_stack: ItemStack = ItemStack.new()
var _slot_refs: Array[SlotRef] = []
var _hovered_slot_index: int = -1
var _window_rect: Rect2 = Rect2()
var _character_rect: Rect2 = Rect2()


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    _initialize_inventory()
    _update_layout()
    queue_redraw()


func _process(_delta: float) -> void:
    var next_hovered_slot_index: int = _find_slot_index_at(get_local_mouse_position())
    if next_hovered_slot_index != _hovered_slot_index:
        _hovered_slot_index = next_hovered_slot_index
        queue_redraw()


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_event: InputEventMouseButton = event as InputEventMouseButton
        if not mouse_event.pressed:
            return
        if mouse_event.button_index == MOUSE_BUTTON_LEFT:
            _handle_left_click(mouse_event.position)
            accept_event()
        elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
            _handle_right_click(mouse_event.position)
            accept_event()


func add_item_to_inventory(item_id: String, count: int) -> int:
    var remaining: int = count
    for slot_index in range(_main_slots.size()):
        var stack: ItemStack = _main_slots[slot_index]
        if stack.is_empty() or stack.item_id != item_id:
            continue
        remaining -= _merge_into_stack(stack, item_id, remaining)
        if remaining <= 0:
            queue_redraw()
            return 0
    for slot_index in range(_main_slots.size()):
        var stack: ItemStack = _main_slots[slot_index]
        if not stack.is_empty():
            continue
        var moved_count: int = mini(remaining, _get_max_stack_size(item_id))
        stack.set_item(item_id, moved_count)
        remaining -= moved_count
        if remaining <= 0:
            queue_redraw()
            return 0
    queue_redraw()
    return remaining


func debug_set_craft_slot(slot_index: int, item_id: String, count: int) -> void:
    if slot_index < 0 or slot_index >= _craft_slots.size():
        return
    _craft_slots[slot_index].set_item(item_id, count)
    queue_redraw()


func debug_get_crafting_result() -> Dictionary[String, Variant]:
    var result: ItemStack = _get_crafting_result()
    return {"item_id": result.item_id, "count": result.count}


func debug_try_take_crafting_result() -> bool:
    return _take_crafting_output()


func _initialize_inventory() -> void:
    if not _main_slots.is_empty():
        return
    _main_slots = _create_slot_array(MAIN_SLOT_COUNT)
    _armor_slots = _create_slot_array(ARMOR_SLOT_COUNT)
    _craft_slots = _create_slot_array(CRAFT_SLOT_COUNT)
    add_item_to_inventory(ITEM_LOG, 8)
    add_item_to_inventory(ITEM_LOG, 12)


func _create_slot_array(count: int) -> Array[ItemStack]:
    var slots: Array[ItemStack] = []
    for slot_index in range(count):
        slots.append(ItemStack.new())
    return slots


func _update_layout() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    _window_rect = Rect2((viewport_size - WINDOW_SIZE) * 0.5, WINDOW_SIZE)
    _slot_refs.clear()

    var armor_x: float = _window_rect.position.x + PANEL_PADDING
    var armor_y: float = _window_rect.position.y + 92.0
    for armor_index in range(ARMOR_SLOT_COUNT):
        var armor_position: Vector2 = Vector2(armor_x, armor_y + float(armor_index) * (SLOT_SIZE + SLOT_GAP))
        _add_slot(GROUP_ARMOR, armor_index, Rect2(armor_position, Vector2(SLOT_SIZE, SLOT_SIZE)))

    _character_rect = Rect2(
        Vector2(_window_rect.position.x + 96.0, _window_rect.position.y + 88.0),
        Vector2(190.0, 246.0)
    )

    var craft_x: float = _window_rect.position.x + 438.0
    var craft_y: float = _window_rect.position.y + 100.0
    for craft_index in range(CRAFT_SLOT_COUNT):
        var craft_column: int = craft_index % 2
        var craft_row: int = craft_index / 2
        var craft_position: Vector2 = Vector2(
            craft_x + float(craft_column) * (SLOT_SIZE + SLOT_GAP),
            craft_y + float(craft_row) * (SLOT_SIZE + SLOT_GAP)
        )
        _add_slot(GROUP_CRAFT, craft_index, Rect2(craft_position, Vector2(SLOT_SIZE, SLOT_SIZE)))

    var output_position: Vector2 = Vector2(craft_x + 178.0, craft_y + 33.0)
    _add_slot(GROUP_OUTPUT, 0, Rect2(output_position, Vector2(SLOT_SIZE, SLOT_SIZE)))

    var inventory_x: float = _window_rect.position.x + 87.0
    var inventory_y: float = _window_rect.position.y + 354.0
    for main_index in range(MAIN_SLOT_COUNT):
        var main_column: int = main_index % 9
        var main_row: int = main_index / 9
        var main_position: Vector2 = Vector2(
            inventory_x + float(main_column) * (SLOT_SIZE + SLOT_GAP),
            inventory_y + float(main_row) * (SLOT_SIZE + SLOT_GAP)
        )
        _add_slot(GROUP_MAIN, main_index, Rect2(main_position, Vector2(SLOT_SIZE, SLOT_SIZE)))


func _add_slot(group: String, slot_index: int, rect: Rect2) -> void:
    _slot_refs.append(SlotRef.new(group, slot_index, rect))


func _draw() -> void:
    _update_layout()
    draw_rect(Rect2(Vector2.ZERO, size), BACKDROP_COLOR, true)
    draw_rect(_window_rect, PANEL_COLOR, true)
    draw_rect(_window_rect, PANEL_BORDER_COLOR, false, 2.0)

    _draw_text("Character", _window_rect.position + Vector2(24.0, 48.0), 18, TEXT_COLOR)
    _draw_text("Crafting", _window_rect.position + Vector2(438.0, 48.0), 18, TEXT_COLOR)
    _draw_character_preview()
    _draw_crafting_arrow()

    for slot_index in range(_slot_refs.size()):
        _draw_slot(slot_index)

    if not _held_stack.is_empty():
        _draw_held_stack()


func _draw_text(text: String, text_position: Vector2, font_size: int, color: Color) -> void:
    var font: Font = get_theme_default_font()
    draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_slot(slot_index: int) -> void:
    var slot: SlotRef = _slot_refs[slot_index]
    var fill_color: Color = SLOT_HOVER_COLOR if slot_index == _hovered_slot_index else SLOT_COLOR
    draw_rect(slot.rect, fill_color, true)
    draw_rect(slot.rect, SLOT_BORDER_COLOR, false, 2.0)

    if slot.group == GROUP_ARMOR:
        _draw_armor_placeholder(slot.index, slot.rect)

    var stack: ItemStack = _get_draw_stack_for_slot(slot)
    if not stack.is_empty():
        _draw_stack_icon(stack, slot.rect)


func _get_draw_stack_for_slot(slot: SlotRef) -> ItemStack:
    if slot.group == GROUP_OUTPUT:
        return _get_crafting_result()
    return _get_slot_stack(slot.group, slot.index)


func _draw_stack_icon(stack: ItemStack, rect: Rect2) -> void:
    var icon_rect: Rect2 = rect.grow(-8.0)
    if stack.item_id == ITEM_LOG:
        _draw_log_icon(icon_rect)
    elif stack.item_id == ITEM_PLANKS:
        _draw_plank_icon(icon_rect)
    else:
        draw_rect(icon_rect, Color(0.72, 0.72, 0.74, 1.0), true)

    var label: String = _get_item_label(stack.item_id)
    var font: Font = get_theme_default_font()
    var label_position: Vector2 = Vector2(icon_rect.position.x + 4.0, icon_rect.end.y - 6.0)
    draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.08, 0.08, 0.08, 1.0))

    if stack.count > 1:
        var count_text: String = str(stack.count)
        var count_font_size: int = 15
        var count_size: Vector2 = font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, count_font_size)
        var count_position: Vector2 = Vector2(rect.end.x - count_size.x - 6.0, rect.position.y + count_font_size + 4.0)
        draw_string(font, count_position + Vector2(1.0, 1.0), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, count_font_size, Color(0.0, 0.0, 0.0, 0.85))
        draw_string(font, count_position, count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, count_font_size, Color(1.0, 1.0, 1.0, 1.0))


func _draw_log_icon(rect: Rect2) -> void:
    draw_rect(rect, Color(0.43, 0.25, 0.12, 1.0), true)
    draw_rect(rect, Color(0.20, 0.11, 0.05, 1.0), false, 2.0)
    var ring_center: Vector2 = rect.position + rect.size * 0.45
    draw_circle(ring_center, rect.size.x * 0.22, Color(0.66, 0.47, 0.25, 1.0))
    draw_circle(ring_center, rect.size.x * 0.11, Color(0.42, 0.25, 0.13, 1.0))
    draw_line(rect.position + Vector2(8.0, rect.size.y - 10.0), rect.end - Vector2(7.0, 10.0), Color(0.22, 0.12, 0.06, 1.0), 2.0)


func _draw_plank_icon(rect: Rect2) -> void:
    draw_rect(rect, Color(0.70, 0.49, 0.24, 1.0), true)
    draw_rect(rect, Color(0.31, 0.19, 0.08, 1.0), false, 2.0)
    for line_index in range(3):
        var line_y: float = rect.position.y + 10.0 + float(line_index) * 10.0
        draw_line(Vector2(rect.position.x + 5.0, line_y), Vector2(rect.end.x - 5.0, line_y + 3.0), Color(0.38, 0.24, 0.10, 0.85), 1.5)


func _draw_armor_placeholder(armor_index: int, rect: Rect2) -> void:
    var icon_color: Color = Color(0.74, 0.74, 0.76, 0.62)
    var icon_rect: Rect2 = rect.grow(-13.0)
    if armor_index == 0:
        draw_rect(Rect2(icon_rect.position + Vector2(5.0, 7.0), Vector2(icon_rect.size.x - 10.0, 18.0)), icon_color, false, 3.0)
        draw_line(icon_rect.position + Vector2(9.0, 24.0), icon_rect.position + Vector2(icon_rect.size.x - 9.0, 24.0), icon_color, 3.0)
    elif armor_index == 1:
        draw_line(icon_rect.position + Vector2(2.0, 7.0), icon_rect.position + Vector2(icon_rect.size.x * 0.5, 3.0), icon_color, 3.0)
        draw_line(icon_rect.position + Vector2(icon_rect.size.x - 2.0, 7.0), icon_rect.position + Vector2(icon_rect.size.x * 0.5, 3.0), icon_color, 3.0)
        draw_rect(Rect2(icon_rect.position + Vector2(8.0, 10.0), Vector2(icon_rect.size.x - 16.0, icon_rect.size.y - 12.0)), icon_color, false, 3.0)
    elif armor_index == 2:
        draw_line(icon_rect.position + Vector2(12.0, 3.0), icon_rect.position + Vector2(12.0, icon_rect.size.y - 2.0), icon_color, 4.0)
        draw_line(icon_rect.position + Vector2(icon_rect.size.x - 12.0, 3.0), icon_rect.position + Vector2(icon_rect.size.x - 12.0, icon_rect.size.y - 2.0), icon_color, 4.0)
        draw_line(icon_rect.position + Vector2(12.0, 4.0), icon_rect.position + Vector2(icon_rect.size.x - 12.0, 4.0), icon_color, 3.0)
    else:
        draw_rect(Rect2(icon_rect.position + Vector2(5.0, 17.0), Vector2(13.0, 11.0)), icon_color, false, 3.0)
        draw_rect(Rect2(icon_rect.position + Vector2(icon_rect.size.x - 18.0, 17.0), Vector2(13.0, 11.0)), icon_color, false, 3.0)


func _draw_character_preview() -> void:
    draw_rect(_character_rect, Color(0.11, 0.12, 0.13, 1.0), true)
    draw_rect(_character_rect, Color(0.34, 0.34, 0.36, 1.0), false, 2.0)

    var center_x: float = _character_rect.position.x + _character_rect.size.x * 0.5
    var top_y: float = _character_rect.position.y + 36.0
    var body_color: Color = Color(0.44, 0.70, 0.86, 1.0)
    var shadow_color: Color = Color(0.05, 0.05, 0.06, 0.45)
    var outline_color: Color = Color(0.03, 0.03, 0.035, 1.0)

    draw_circle(Vector2(center_x, _character_rect.end.y - 17.0), 42.0, shadow_color)
    draw_circle(Vector2(center_x, top_y + 32.0), 33.0, body_color)
    draw_circle(Vector2(center_x, top_y + 32.0), 34.5, outline_color, false, 2.0)
    draw_rect(Rect2(Vector2(center_x - 32.0, top_y + 67.0), Vector2(64.0, 72.0)), Color(0.27, 0.55, 0.73, 1.0), true)
    draw_rect(Rect2(Vector2(center_x - 32.0, top_y + 67.0), Vector2(64.0, 72.0)), outline_color, false, 2.0)
    draw_line(Vector2(center_x - 31.0, top_y + 80.0), Vector2(center_x - 60.0, top_y + 124.0), body_color, 12.0)
    draw_line(Vector2(center_x + 31.0, top_y + 80.0), Vector2(center_x + 60.0, top_y + 124.0), body_color, 12.0)
    draw_line(Vector2(center_x - 16.0, top_y + 138.0), Vector2(center_x - 24.0, top_y + 190.0), body_color, 13.0)
    draw_line(Vector2(center_x + 16.0, top_y + 138.0), Vector2(center_x + 24.0, top_y + 190.0), body_color, 13.0)
    draw_circle(Vector2(center_x - 12.0, top_y + 27.0), 5.0, Color(1.0, 1.0, 1.0, 1.0))
    draw_circle(Vector2(center_x + 12.0, top_y + 27.0), 5.0, Color(1.0, 1.0, 1.0, 1.0))
    draw_circle(Vector2(center_x - 12.0, top_y + 28.0), 2.5, Color(0.05, 0.05, 0.05, 1.0))
    draw_circle(Vector2(center_x + 12.0, top_y + 28.0), 2.5, Color(0.05, 0.05, 0.05, 1.0))


func _draw_crafting_arrow() -> void:
    var start: Vector2 = Vector2(_window_rect.position.x + 578.0, _window_rect.position.y + 162.0)
    var end: Vector2 = Vector2(_window_rect.position.x + 608.0, _window_rect.position.y + 162.0)
    draw_line(start, end, Color(0.70, 0.70, 0.70, 1.0), 4.0)
    draw_line(end, end + Vector2(-9.0, -9.0), Color(0.70, 0.70, 0.70, 1.0), 4.0)
    draw_line(end, end + Vector2(-9.0, 9.0), Color(0.70, 0.70, 0.70, 1.0), 4.0)


func _draw_held_stack() -> void:
    var mouse_position: Vector2 = get_local_mouse_position()
    var held_rect: Rect2 = Rect2(mouse_position - Vector2(SLOT_SIZE, SLOT_SIZE) * 0.5, Vector2(SLOT_SIZE, SLOT_SIZE))
    _draw_stack_icon(_held_stack, held_rect)


func _handle_left_click(position: Vector2) -> void:
    var slot_index: int = _find_slot_index_at(position)
    if slot_index == -1:
        return
    var slot: SlotRef = _slot_refs[slot_index]
    if slot.group == GROUP_OUTPUT:
        _take_crafting_output()
    else:
        _interact_with_slot(slot, false)
    queue_redraw()


func _handle_right_click(position: Vector2) -> void:
    var slot_index: int = _find_slot_index_at(position)
    if slot_index == -1:
        return
    var slot: SlotRef = _slot_refs[slot_index]
    if slot.group != GROUP_OUTPUT:
        _interact_with_slot(slot, true)
    queue_redraw()


func _interact_with_slot(slot: SlotRef, split_or_single: bool) -> void:
    var slot_stack: ItemStack = _get_slot_stack(slot.group, slot.index)
    if split_or_single:
        _interact_with_slot_right_click(slot, slot_stack)
    else:
        _interact_with_slot_left_click(slot, slot_stack)


func _interact_with_slot_left_click(slot: SlotRef, slot_stack: ItemStack) -> void:
    if _held_stack.is_empty():
        if not slot_stack.is_empty():
            _held_stack.copy_from(slot_stack)
            slot_stack.clear()
        return
    if not _slot_accepts_item(slot, _held_stack.item_id):
        return
    if slot_stack.is_empty():
        slot_stack.copy_from(_held_stack)
        _held_stack.clear()
    elif slot_stack.item_id == _held_stack.item_id:
        var moved_count: int = _merge_into_stack(slot_stack, _held_stack.item_id, _held_stack.count)
        _held_stack.count -= moved_count
        if _held_stack.count <= 0:
            _held_stack.clear()
    else:
        var swap_stack: ItemStack = slot_stack.duplicate_stack()
        slot_stack.copy_from(_held_stack)
        _held_stack.copy_from(swap_stack)


func _interact_with_slot_right_click(slot: SlotRef, slot_stack: ItemStack) -> void:
    if _held_stack.is_empty():
        if slot_stack.is_empty():
            return
        var split_count: int = ceili(float(slot_stack.count) * 0.5)
        _held_stack.set_item(slot_stack.item_id, split_count)
        slot_stack.count -= split_count
        if slot_stack.count <= 0:
            slot_stack.clear()
        return
    if not _slot_accepts_item(slot, _held_stack.item_id):
        return
    if slot_stack.is_empty():
        slot_stack.set_item(_held_stack.item_id, 1)
        _held_stack.count -= 1
    elif slot_stack.item_id == _held_stack.item_id and slot_stack.count < _get_max_stack_size(slot_stack.item_id):
        slot_stack.count += 1
        _held_stack.count -= 1
    if _held_stack.count <= 0:
        _held_stack.clear()


func _take_crafting_output() -> bool:
    var result: ItemStack = _get_crafting_result()
    if result.is_empty():
        return false
    if _held_stack.is_empty():
        _held_stack.copy_from(result)
        _consume_crafting_ingredient()
        queue_redraw()
        return true
    if _held_stack.item_id != result.item_id:
        return false
    if _held_stack.count + result.count > _get_max_stack_size(result.item_id):
        return false
    _held_stack.count += result.count
    _consume_crafting_ingredient()
    queue_redraw()
    return true


func _get_crafting_result() -> ItemStack:
    var occupied_slots: int = 0
    var has_log: bool = false
    for craft_index in range(_craft_slots.size()):
        var stack: ItemStack = _craft_slots[craft_index]
        if stack.is_empty():
            continue
        occupied_slots += 1
        if stack.item_id == ITEM_LOG:
            has_log = true
    if occupied_slots == 1 and has_log:
        return ItemStack.new(ITEM_PLANKS, 4)
    return ItemStack.new()


func _consume_crafting_ingredient() -> void:
    for craft_index in range(_craft_slots.size()):
        var stack: ItemStack = _craft_slots[craft_index]
        if stack.item_id == ITEM_LOG and stack.count > 0:
            stack.count -= 1
            if stack.count <= 0:
                stack.clear()
            return


func _slot_accepts_item(slot: SlotRef, item_id: String) -> bool:
    if slot.group == GROUP_ARMOR:
        return item_id.begins_with("armor_")
    if slot.group == GROUP_OUTPUT:
        return false
    return true


func _merge_into_stack(stack: ItemStack, item_id: String, amount: int) -> int:
    if amount <= 0:
        return 0
    if stack.is_empty():
        var moved_to_empty: int = mini(amount, _get_max_stack_size(item_id))
        stack.set_item(item_id, moved_to_empty)
        return moved_to_empty
    if stack.item_id != item_id:
        return 0
    var available_space: int = _get_max_stack_size(item_id) - stack.count
    var moved_count: int = mini(amount, available_space)
    stack.count += moved_count
    return moved_count


func _get_slot_stack(group: String, slot_index: int) -> ItemStack:
    if group == GROUP_MAIN:
        return _main_slots[slot_index]
    if group == GROUP_ARMOR:
        return _armor_slots[slot_index]
    if group == GROUP_CRAFT:
        return _craft_slots[slot_index]
    return ItemStack.new()


func _find_slot_index_at(position: Vector2) -> int:
    for slot_index in range(_slot_refs.size()):
        var slot: SlotRef = _slot_refs[slot_index]
        if slot.rect.has_point(position):
            return slot_index
    return -1


func _get_max_stack_size(_item_id: String) -> int:
    return MAX_STACK_SIZE


func _get_item_label(item_id: String) -> String:
    if item_id == ITEM_LOG:
        return "LOG"
    if item_id == ITEM_PLANKS:
        return "PLK"
    return "ITEM"
