#include <libproc.h>
#include <mach/mach_time.h>
#include <sys/resource.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
static double now(void) {struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec/1e9;}
int main(int argc,char **argv) {
 if(argc<3)return 2;
 int pid=atoi(argv[1]),samples=atoi(argv[2]);
 mach_timebase_info_data_t tb;mach_timebase_info(&tb);double tickToNanoseconds=(double)tb.numer/tb.denom;
 struct rusage_info_v6 previous={0};double previousTime=now();
 if(proc_pid_rusage(pid,RUSAGE_INFO_V6,(rusage_info_t*)&previous)){perror("rusage");return 1;}
 puts("sample,cpu_percent,footprint_mb,rss_mb,energy_nj_delta,estimated_process_watts,pkg_wakeups_per_s,interrupt_wakeups_per_s");fflush(stdout);
 for(int i=0;i<samples;i++) {
  struct timespec pause={2,0};nanosleep(&pause,NULL);
  struct rusage_info_v6 current={0};double currentTime=now();
  if(proc_pid_rusage(pid,RUSAGE_INFO_V6,(rusage_info_t*)&current)){perror("rusage");return 1;}
  double dt=currentTime-previousTime;
  unsigned long long delta=current.ri_energy_nj-previous.ri_energy_nj;
  printf("%d,%.3f,%.3f,%.3f,%llu,%.6f,%.3f,%.3f\n",i,(current.ri_user_time+current.ri_system_time-previous.ri_user_time-previous.ri_system_time)*tickToNanoseconds/1e9/dt*100,current.ri_phys_footprint/1048576.0,current.ri_resident_size/1048576.0,delta,delta/1e9/dt,(current.ri_pkg_idle_wkups-previous.ri_pkg_idle_wkups)/dt,(current.ri_interrupt_wkups-previous.ri_interrupt_wkups)/dt);
  fflush(stdout);previous=current;previousTime=currentTime;
 }
}
