# RaidBuffChecker v1.0

**RaidBuffChecker** (conocido como **bufos**) es un addon de escaneo y control de beneficios de banda para **World of Warcraft 3.3.5a (WotLK)**, optimizado para el servidor **NaerZone**. Permite comprobar en tiempo real qué jugadores tienen o les faltan los bufos necesarios de clase (paladín, sacerdote, mago, druida, guerrero), facilitando la asignación y el reporte rápido a la banda.

---

## 🚀 Funcionalidades y Módulos

| Módulo / Comando | Descripción |
|---|---|
| **Escaneo de Banda** | Comprueba beneficios de banda clásicos (Reyes, Sabiduría, Poderío, Salvaguarda, Entereza, Sombra, Espíritu, Marca, Intelecto, Grito de batalla) en los subgrupos 1 al 5. |
| **Reporte Inteligente** | Alertas en chat de alerta de banda (`/rw`), chat de banda (`/raid`), o localmente en el chat de Blizzard si estás solo o en grupo pequeño. |
| **Asignaciones (Config)** | Menú interactivo (`/rbc config` o clic derecho en el botón) para asignar responsables por clase con selectores dinámicos en línea. |
| **Rastreo Silencioso** | Panel lateral independiente y movible que muestra en tiempo real la lista de nombres faltantes de cada buff, sin saturar el chat de banda. |
| **Enfoques de Magia** | Módulo de magos automático que calcula y genera una cadena circular o intercambio cruzado de *Enfoque de Magia* entre todos los magos activos de la banda. |
| **Tambores y Pergaminos** | Soporta la asignación y control de buffs mediante consumibles si no hay clases disponibles en el grupo o banda. |

> **Uso Inteligente en Combate**: Las ventanas del addon se cerrarán automáticamente si entras en combate para priorizar el rendimiento y la seguridad del juego.

---

## 🛠️ Instalación

1. Copia la carpeta `bufos` en `World of Warcraft\Interface\Addons\`
2. Asegúrate de que la carpeta se llame exactamente `bufos`
3. Actívalo en el menú de Addons al iniciar el juego o recarga la interfaz con `/reload`

---

## 📖 Uso Rápido

- **Clic Izquierdo** en el botón de pantalla para realizar un escaneo completo de banda.
- **Clic Derecho** o **Alt + Clic** en el botón de pantalla para abrir/cerrar el menú de asignaciones.
- **Shift + Arrastrar** sobre el botón principal para reposicionarlo libremente en tu pantalla.
- **Botón 🚫 (Reset)** en la ventana de configuración para desasignar o limpiar rápidamente un campo.
- **Comandos de Chat**:
  - `/rbc` — Realiza el escaneo de banda.
  - `/rbc config` / `/rbc menu` / `/kmin` — Abre la ventana de configuración y asignaciones.

---

## 💻 Desarrollo

Desarrollado por **Zorrorojo/Miabuelita** hermandad **<Sedentarios>** para el servidor NaerZone.
