# Mindset

Juego 2D hecho en Godot 4.7 (proyecto originalmente llamado "Xalapa Punk").

## Estructura del proyecto

```
mindset/
├── assets/
│   ├── sprites/
│   │   ├── oliver/       # Sprites del personaje principal
│   │   └── mapple/       # Sprite del compañero "Mapple"
│   └── backgrounds/      # Fondos de niveles
├── scenes/
│   └── main.tscn         # Escena principal
├── scripts/
│   └── player.gd         # Lógica del personaje (movimiento, ataque, bullet time)
├── icon.svg               # Icono del proyecto
└── project.godot
```

## Requisitos

- Godot Engine 4.7+

## Cómo abrir el proyecto

1. Clona el repositorio.
2. Abre Godot Engine y selecciona "Importar", eligiendo la carpeta del repo (donde está `project.godot`).
3. Godot regenerará automáticamente la carpeta `.godot/` (caché local, no se sube al repo).
