# Seguridad y verificación

## Diseño

- El sitio publicado contiene exclusivamente archivos estáticos y una clave pública de Supabase. Los secretos de servidor permanecen en el entorno administrado de Supabase.
- `brunch_entries` no permite lecturas ni escrituras a visitantes. Los usuarios autenticados solo pueden leer si están en la lista privada de organización y presentan un token con segundo factor verificado (`aal2`).
- La función pública `submit-quiz` valida tamaño, tipo, consentimiento, nombre y nueve identificadores de estilo. La función SQL privada vuelve a validar y calcula puntuaciones y todos los empates. Los reintentos usan un UUID y un bloqueo transaccional para evitar duplicados.
- Los límites son seis registros por minuto y sesenta por hora por bucket de red, y mil por hora en total. No se guardan IP en claro. La identificación de red depende del encabezado que entrega la plataforma; los límites no sustituyen un WAF ni impiden todo ataque distribuido.
- La creación pública de cuentas está desactivada. El administrador se crea desde el panel de Supabase y se autoriza por UUID. El segundo factor debe completarlo su titular.
- El navegador muestra texto de nombres mediante `textContent`, sin interpretarlo como HTML. La exportación CSV neutraliza prefijos que pueden activar fórmulas.
- Las sesiones administrativas viven en memoria, sin almacenamiento persistente. El avance de la participante sí se conserva localmente, con un control para borrar la copia del dispositivo al terminar.
- Las imágenes y los estilos se sirven desde el sitio. No se cargan bibliotecas, fuentes ni analítica desde CDN.
- GitHub Actions publica una lista explícita de archivos, con permisos mínimos, sin credenciales persistentes en el checkout y acciones oficiales fijadas por SHA.

## Pruebas realizadas el 25 de octubre de 2026

- Siete pruebas locales: asociaciones de las nueve preguntas, ganadores únicos, empates de dos y tres estilos, respuestas inválidas, aleatorización y CSV.
- `supabase/tests.sql`: puntuación, idempotencia, conflicto de reintento, validación, límite de frecuencia, privilegios y RLS. Datos de prueba revertidos en la misma transacción.
- API pública: lectura y modificación directa rechazadas (401), invocación directa de la función SQL rechazada (401), formulario inválido rechazado (400) y origen ajeno rechazado (403).
- Navegador: recorrido completo de nueve preguntas, orden conservado al retroceder, empate Romántico/Natural y registro confirmado por servidor.
- Verificación de ancho en 390 y 820 píxeles sin desbordamiento horizontal.

## Límites y mantenimiento

La seguridad de la infraestructura administrada depende de las actualizaciones de GitHub y Supabase. Los parches de PHP, Node.js, GitLab y NGINX de octubre de 2026 se evaluaron al seleccionar una aplicación sin esos servidores autogestionados. El Node.js local encontrado es 24.15.0: se utilizó para comprobaciones locales de código propio, y debe actualizarse antes de usarlo como servidor público o para procesamiento externo. La publicación utiliza el entorno administrado de GitHub.

La política CSP de GitHub Pages se declara en HTML. Pages no permite configurar libremente todos los encabezados HTTP; controles como `frame-ancestors` requieren un proveedor o proxy que permita esos encabezados. No se presenta la CSP en HTML como sustituto de todos los controles de servidor.

La solicitud de eliminación de datos se gestiona por el WhatsApp de organización. Acordar una fecha de eliminación tras el evento. Conservar exportaciones solo en dispositivos de la organización. La infraestructura y la cuenta deben mantenerse actualizadas; estas pruebas no equivalen a una garantía de ausencia de vulnerabilidades.
