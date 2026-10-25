export const styleIds = ['clasico','romantico','dramatico','natural','creativo','seductor','elegante'];
export const styles = {
  clasico: {name:'Clásico', words:'Equilibrio · Atemporalidad · Confianza', description:'Te identificas con una imagen cuidada y prendas que conservan su encanto con el paso del tiempo.'},
  romantico: {name:'Romántico', words:'Delicadeza · Suavidad · Calidez', description:'Los detalles delicados y una expresión suave y femenina conectan con tu forma de vestir.'},
  dramatico: {name:'Dramático', words:'Presencia · Fuerza · Impacto', description:'Te atraen las combinaciones con carácter y una imagen que deja huella.'},
  natural: {name:'Natural', words:'Comodidad · Frescura · Cercanía', description:'Tu forma de vestir conecta con la comodidad, la sencillez y la libertad de ser tú misma.'},
  creativo: {name:'Creativo', words:'Originalidad · Expresión · Libertad', description:'Disfrutas expresar tu personalidad con mezclas inesperadas y detalles que se sienten tuyos.'},
  seductor: {name:'Seductor', words:'Seguridad · Sensualidad · Magnetismo', description:'Te gusta destacar tu silueta y expresar seguridad a través de lo que llevas.'},
  elegante: {name:'Elegante', words:'Armonía · Sofisticación · Detalle', description:'Te identificas con una imagen pulida, armoniosa y atenta a los pequeños detalles.'},
};
// Columns follow the nine-question scoring table supplied by the organizer.
export const questions = [
 ['¿Cómo quieres sentirte al vestir?', ['Equilibrada y clásica','Femenina y delicada','Poderosa y llamativa','Cómoda y natural','Creativa y auténtica','Sensual y atractiva','Elegante y sofisticada']],
 ['¿Qué prendas llaman tu atención al comprar?', ['Atemporales','Con detalles delicados','Estructuradas y atrevidas','Básicas y versátiles','Originales y diferentes','Que realzan la silueta','De calidad y cortes impecables']],
 ['¿Qué combinación elegirías para un día de actividades personales?', ['Pantalón recto y camisa clásica','Falda fluida y blusa delicada','Combinación audaz y contrastante','Jeans, camiseta y zapatos cómodos','Mezcla de colores y estampados','Jeans ajustados y top favorecedor','Conjunto coordinado y refinado']],
 ['¿Qué colores predominan o te gustaría incorporar en tu closet?', ['Blanco, negro, azul marino y beige','Pasteles y tonos suaves','Colores fuertes y contrastes','Neutros y tonos tierra','Colores variados y experimentales','Rojo, negro, vino y tonos intensos','Neutros sofisticados y armoniosos']],
 ['¿Qué tipo de accesorios prefieres?', ['Clásicos y discretos','Perlas y detalles delicados','Grandes y geométricos','Prácticos y cómodos','Artísticos y poco convencionales','Sensuales y llamativos','Refinados y de buena calidad']],
 ['¿Qué característica define tu forma de vestir?', ['Atemporalidad','Delicadeza','Impacto','Funcionalidad','Originalidad','Sensualidad','Sofisticación']],
 ['¿Qué imagen te gustaría proyectar en el entorno profesional?', ['Profesional y confiable','Amable y femenina','Firme y poderosa','Cercana y natural','Innovadora y auténtica','Segura y atractiva','Refinada y distinguida']],
 ['¿Cómo prefieres combinar las prendas de tu armario?', ['Combinaciones probadas y atemporales','Conjuntos femeninos y delicados','Contrastes y elementos protagonistas','Combinaciones sencillas y cómodas','Mezclas originales de texturas y colores','Conjuntos que resaltan la figura','Conjuntos armoniosos y pulidos']],
 ['¿Qué hace que te identifiques con un outfit?', ['Es clásico y versátil','Tiene detalles delicados','Tiene fuerza visual','Es cómodo y relajado','Refleja originalidad','Es sensual y favorecedor','Es sofisticado y armonioso']],
].map(([text, options], index) => ({id:index+1, text, options:options.map((text,i)=>({id:styleIds[i],text}))}));

export function scoreAnswers(answers, selection = {}) {
 if (!Array.isArray(answers) || answers.length !== 9 || answers.some(id=>!styleIds.includes(id))) throw new Error('Responde las nueve preguntas.');
 const scores = Object.fromEntries(styleIds.map(id=>[id,0]));
 answers.forEach(id=>scores[id]++);
 const max = Math.max(...Object.values(scores));
 const winners=styleIds.filter(id=>scores[id]===max);
 let primary=[...winners], secondary=[], needsChoice=null;
 const choose=(role,candidates,count)=>{
  const selected=selection?.[role] ?? [];
  if(!Array.isArray(selected)||selected.length!==count||new Set(selected).size!==count||selected.some(id=>!candidates.includes(id))){
   needsChoice={role,candidates,count};return [];
  }
  return candidates.filter(id=>selected.includes(id));
 };
 if(primary.length>3)primary=choose('primary',primary,3);
 else if(primary.length<3){
  const next=Math.max(0,...styleIds.filter(id=>scores[id]<max).map(id=>scores[id]));
  const candidates=next>0?styleIds.filter(id=>scores[id]===next):[];
  const room=3-primary.length;
  secondary=candidates.length>room?choose('secondary',candidates,room):candidates;
 }
 return {scores,winners,primary,secondary,needsChoice};
}
export function shuffle(items, random = Math.random) {
 const copy=[...items];
 for(let i=copy.length-1;i>0;i--){const j=Math.floor(random()*(i+1)); [copy[i],copy[j]]=[copy[j],copy[i]];}
 return copy;
}
export function csvCell(value) {
 let text=String(value ?? '');
 if (/^[\s]*[=+@\-\t\r\n]/.test(text)) text="'"+text;
 return '"'+text.replaceAll('"','""')+'"';
}
