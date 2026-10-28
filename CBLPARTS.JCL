//CBLPARTS JOB MSGLEVEL=1,MSGCLASS=A,CLASS=A,                        
//            TIME=1440,REGION=0M,                                   
//            MEMLIMIT=NOLIMIT                                       
//*                                                                  
//MPR00001 PROC AGN=,ALTID=,APARM=,APPLFE=,CL1=XXX,CL2=XXX,          
//            CL3=XXX,CL4=XXX,DBLDL=,ENVIRON=DFSJVMEV,IMSID=IVP1,    
//            JVMOPMAS=DFSJVMMS,LOCKMAX=,NBA=5,OBA=5,OPT=W,OVLA=0,   
//            PARDLI=,PCB=040,PREINIT=,PRLD=,PWFI=N,SOD=,SPIE=0,     
//            SSM=,STIMER=0,TLIM=01,VALCK=0,VFREE=,VSFX=,JVM=3164    
//*                                                                  
//REGION   EXEC PGM=DFSRRC00,                                        
//            PARM=(MSG,&CL1&CL2&CL3&CL4,                            
//            &OPT&OVLA&SPIE&VALCK&TLIM&PCB,&PRLD,&STIMER,&SOD,      
//            &DBLDL,&NBA,&OBA,&IMSID,&AGN,&VSFX,&VFREE,&SSM,        
//            &PREINIT,&ALTID,&PWFI,&APARM,&LOCKMAX,&APPLFE,         
//            &ENVIRON,&JVMOPMAS,&PARDLI,&JVM)                       
//STEPLIB  DD DISP=SHR,DSN='YOUR_IMS_HLQ'.SDFSRESL                           
//         DD DISP=SHR,DSN='YOUR_IMS_HLQ'.PGMLIB2                            
//         DD DISP=SHR,DSN='YOUR_IMS_HLQ'.SDFSJLIB                           
//PROCLIB  DD DISP=SHR,                                
//            DSN='YOUR_IMS_HLQ'.PROCLIB                       
//PRINTDD  DD SYSOUT=*                                 
//SYSPRINT DD SYSOUT=*                                 
//DFSSTAT  DD SYSOUT=*                                 
//SYSOUT   DD SYSOUT=*                                 
//STDOUT   DD SYSOUT=*                                 
//STDENV   DD PATH='/your/path/to/stdenv00.cfg',  
//            PATHOPTS=ORDONLY,                        
//            FILEDATA=TEXT                            
//         PEND                                        
//STEP1    EXEC MPR00001                               