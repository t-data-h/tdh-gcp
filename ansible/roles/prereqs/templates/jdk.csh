setenv JDK_HOME /usr/lib/jvm/java
setenv JRE_HOME /usr/lib/jvm/java/jre
setenv JAVA_HOME ${JDK_HOME}
setenv DERBY_HOME ${JDK_HOME}/db
setenv PATH ${PATH}:${JDK_HOME}/bin:${JRE_HOME}/bin:${DERBY_HOME}/bin
