# Inovelli Switch Automation Pattern

These Inovelli switches (sold as "Inovelli On/Off Switch" but flashed with Red Series firmware) appear in Home Assistant as Matter devices with button entities.

## Button Entity Naming Convention

Each switch has 3 button entities:
- `event.{device}_button_up` - Up button
- `event.{device}_button_down` - Down button
- `event.{device}_button_config` - Config button

## Event Types

Buttons fire `state_changed` events with these event types in the attributes:
- `multi_press_1` - Single press
- `multi_press_2` - Double press
- `multi_press_3` - Triple press
- `multi_press_4` - Quad press
- `multi_press_5` - Quintuple press
- `long_press` - Long press
- `long_release` - Long press release

## Automation Template

```yaml
- id: device_button_up
  alias: Device - Button Up Action
  trigger:
    - platform: state
      entity_id: event.device_button_up
  condition:
    - condition: template
      value_template: >
        {{ trigger.to_state.attributes.event_type == 'multi_press_1' }}
  action:
    - service: light.turn_on
      target:
        entity_id: light.device
  mode: single
```

## Current Automations

| Entity ID | Device | Action |
|-----------|--------|--------|
| `event.bar_lights_button_up` | Bar Lights | Turn on lights |
| `event.bar_lights_button_down` | Bar Lights | Turn off lights |

## Example: Double Press to Toggle

```yaml
- id: device_button_up_double_press
  alias: Device - Button Up Double Press
  trigger:
    - platform: state
      entity_id: event.device_button_up
  condition:
    - condition: template
      value_template: >
        {{ trigger.to_state.attributes.event_type == 'multi_press_2' }}
  action:
    - service: light.toggle
      target:
        entity_id: light.device
  mode: single
```
