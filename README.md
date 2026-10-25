# Un brunch con estilo

Sitio estático para el encuentro de Johanna Disent del 31 de octubre de 2026.

## Resultado predominante y secundario

Cada respuesta suma un punto. Se muestran los estilos de la puntuación más alta como predominantes y los de la siguiente puntuación positiva como secundarios, hasta tres estilos en total. Si empatan más estilos de los que caben, la participante elige entre los empatados: tres predominantes cuando hay más de tres en primer lugar, uno secundario cuando ya hay dos predominantes, o dos secundarios cuando hay un predominante. La elección no cambia puntuaciones. Con tres predominantes no se agrega un cuarto estilo; con nueve respuestas del mismo estilo no se inventa un secundario de cero puntos.

La migración `202610250002_primary_secondary.sql` conserva respuestas y puntuaciones previas, añade los roles derivados y aplica el mismo criterio en servidor. `tests-v2.sql` verifica los casos principales y la imposibilidad de cambiar el desempate después de guardarlo. El panel indica «Desempate pendiente» en registros anteriores que requieran una elección de la participante.

## Desarrollo

Servir esta carpeta con un servidor HTTP local en el puerto 4173. No se necesita instalar dependencias para el sitio. `npm test` ejecuta las pruebas del cuestionario y la exportación CSV. Usar herramientas con soporte vigente y parches de seguridad aplicados.

## Publicación

GitHub Pages debe publicar únicamente la carpeta `public-site` generada por el flujo de publicación; se incluyen HTML, CSS, JS y assets, nunca migraciones, pruebas ni archivos privados.

## Supabase

Proyecto: `ebjutzozewrxrvuhmlvy`. `config.js` solo admite URL y clave pública. La función `submit-quiz` usa los secretos del entorno de Supabase. Su verificación JWT de plataforma está desactivada porque recibe un formulario público: valida el cuerpo y solo invoca una función SQL reservada a `service_role`.

La migración en `supabase/migrations/` se ejecuta una vez. Contiene tablas con RLS, una lista privada de administradores y puntuación calculada en servidor. Solo la función de servidor puede registrar resultados. La lectura requiere un usuario expresamente autorizado y un token `aal2` (segundo factor verificado).

## Administración

1. Crear el usuario de organización directamente en Supabase Auth con un correo controlado por la organización. La contraseña debe introducirla su titular, nunca guardarse en el repositorio.
2. Autorizar su UUID mediante `insert into brunch_private.admins(user_id) values ('UUID-DEL-USUARIO');` desde el SQL Editor.
3. Abrir `admin.html`, iniciar sesión y registrar una aplicación de autenticación TOTP. El panel exige el código de segundo factor antes de leer resultados.
4. Cerrar sesión al terminar. Los tokens del panel viven solo en memoria. La exportación CSV incluye únicamente los registros visibles por los permisos de base de datos.

## Datos y seguridad

Se guardan nombre, respuestas, puntuaciones, estilos, fecha y versión del consentimiento. Los contadores de frecuencia usan un hash diario con secreto del servidor, no direcciones IP en claro. Mantener los contadores durante el evento; después, eliminarlos junto con los registros que ya no deban conservarse, con aprobación de la organización. Las participantes pueden solicitar eliminación por WhatsApp.

El avance y el resultado se conservan en el almacenamiento local del navegador. El control de borrado de la tarjeta borra esa copia, no el registro de organización. No hay analítica, fuentes remotas ni bibliotecas cargadas desde CDN. Las imágenes de estilo proceden del Word facilitado por la organización.

Los límites por origen y el campo señuelo son defensa adicional, no autenticación ni protección absoluta frente a bots. La función limita el tamaño de la petición y los registros por dirección y por hora; las pruebas deben verificar también los permisos directamente en la API. La infraestructura administrada sigue dependiendo de los parches de GitHub y Supabase.
