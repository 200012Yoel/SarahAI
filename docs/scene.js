import * as THREE from 'three';
import { GLTFLoader } from './assets/GLTFLoader.js';
import { RoomEnvironment } from './assets/RoomEnvironment.js';
const host=document.querySelector('#scene'),poster=document.querySelector('#poster');
const replay=document.querySelector('#replay'),turn=document.querySelector('#turn'),phase=document.querySelector('#phase');
const reduced=matchMedia('(prefers-reduced-motion: reduce)');
let renderer,mixer,phone,camera,scene,clock,raf=0,elapsed=0,duration=8,playing=false,visible=true,angle=0,targetAngle=0,actions=[];
function fallback(){if(raf)cancelAnimationFrame(raf);raf=0;playing=false;poster.style.opacity='1';renderer?.domElement.remove();renderer?.dispose();replay.disabled=true;turn.disabled=true;phase.textContent='Bleu Élixir · Sarah IA';}
function schedule(){if(!raf&&visible&&!document.hidden)raf=requestAnimationFrame(draw);}
function draw(){raf=0;const dt=Math.min(clock.getDelta(),.05);if(playing){elapsed=Math.min(duration,elapsed+dt);mixer.setTime(elapsed);if(elapsed>=duration){playing=false;phase.textContent='Sarah IA prend vie.';turn.disabled=false;}else phase.textContent=elapsed<4.8?'Chaque pièce trouve sa place.':'Sarah IA s’éveille.';}angle=reduced.matches?targetAngle:THREE.MathUtils.damp(angle,targetAngle,6,dt);phone.rotation.y=angle+.32;phone.rotation.z=-.10;phone.rotation.x=.07;renderer.render(scene,camera);if(playing||Math.abs(angle-targetAngle)>.001)schedule();}
function resize(){if(!renderer)return;const w=host.clientWidth,h=host.clientHeight;if(!w||!h)return;renderer.setSize(w,h,false);const height=.215;camera.left=-height*w/h/2;camera.right=height*w/h/2;camera.top=height/2;camera.bottom=-height/2;camera.updateProjectionMatrix();schedule();}
function start(){elapsed=0;angle=targetAngle=0;turn.querySelector('span').textContent='Voir le dos';playing=true;turn.disabled=true;for(const a of actions){a.reset();a.play();}clock.getDelta();schedule();}
try{
 renderer=new THREE.WebGLRenderer({alpha:true,antialias:true,powerPreference:'low-power'});renderer.setPixelRatio(Math.min(devicePixelRatio,1.75));renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.2;host.append(renderer.domElement);
 scene=new THREE.Scene();camera=new THREE.OrthographicCamera(-.12,.12,.12,-.12,.001,10);camera.position.set(0,0,.4);camera.lookAt(0,0,0);
 const generator=new THREE.PMREMGenerator(renderer),room=new RoomEnvironment();scene.environment=generator.fromScene(room,.04).texture;room.dispose();generator.dispose();
 scene.add(new THREE.HemisphereLight(0xc7ddff,0x111c40,.6));const key=new THREE.DirectionalLight(0xd1e3ff,1.3);key.position.set(-1,2,3);scene.add(key);
 const gltf=await new GLTFLoader().loadAsync('./assets/elixir.glb');
 // Blender exports metres and converts Z-up to Y-up. A wrapper restores the portrait phone plane.
 phone=new THREE.Group();scene.add(phone);const orientation=new THREE.Group();orientation.rotation.x=Math.PI/2;phone.add(orientation);orientation.add(gltf.scene);
 gltf.scene.traverse(o=>{if(o.isLight)o.intensity=0;});
 mixer=new THREE.AnimationMixer(gltf.scene);duration=Math.max(...gltf.animations.map(a=>a.duration),8);gltf.animations.forEach(clip=>{const a=mixer.clipAction(clip);a.setLoop(THREE.LoopOnce,1);a.clampWhenFinished=true;a.play();actions.push(a);});
 clock=new THREE.Clock();resize();poster.style.opacity='0';replay.disabled=false;
 if(reduced.matches){mixer.setTime(duration);phase.textContent='Sarah IA prend vie.';turn.disabled=false;schedule();}else start();
 new ResizeObserver(resize).observe(host);
 new IntersectionObserver(entries=>{visible=entries[0].isIntersecting;if(visible){clock.getDelta();schedule();}else{cancelAnimationFrame(raf);raf=0;}},{threshold:.05}).observe(host);
 document.addEventListener('visibilitychange',()=>{if(document.hidden){cancelAnimationFrame(raf);raf=0;}else{clock.getDelta();schedule();}});
 renderer.domElement.addEventListener('webglcontextlost',e=>{e.preventDefault();fallback();});
 replay.addEventListener('click',start);
 turn.addEventListener('click',()=>{targetAngle=targetAngle===0?Math.PI:0;turn.querySelector('span').textContent=targetAngle?'Voir l’écran':'Voir le dos';clock.getDelta();schedule();});
 reduced.addEventListener('change',()=>{if(reduced.matches){playing=false;mixer.setTime(duration);turn.disabled=false;phase.textContent='Sarah IA prend vie.';schedule();}});
}catch(error){console.warn('3D unavailable; displaying the rendered phone.',error);fallback();}
