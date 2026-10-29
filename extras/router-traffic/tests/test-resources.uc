import {cpuUsage} from '../app/resources.uc';
for(let i=0;i<3;i++){
 assert(cpuUsage(null,{total:100,idle:20})==null);
 assert(cpuUsage({total:100,idle:20},{total:200,idle:40})==80);
 assert(cpuUsage({total:100,idle:20},{total:200,idle:120})==0);
 assert(cpuUsage({total:100,idle:20},{total:200,idle:20})==100);
 assert(cpuUsage({total:100,idle:20},{total:100,idle:20})==null);
 assert(cpuUsage({total:100,idle:20},{total:90,idle:10})==null);
 assert(cpuUsage({total:100,idle:20},{total:200,idle:200})==null);
}
print('PASS CPU first sample, actual deltas, idle, full load, duplicate, reset and invalid idle (three rounds)\n');
