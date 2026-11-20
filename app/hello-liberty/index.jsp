<%@ page contentType="text/plain;charset=UTF-8" %><%
    String host = java.net.InetAddress.getLocalHost().getHostName();
%>Hello from Open Liberty, deployed by Ansible!
Server info : <%= application.getServerInfo() %>
Node        : <%= System.getenv().getOrDefault("DEMO_NODE_NAME", host) %>
Hostname    : <%= host %>
Environment : <%= System.getenv().getOrDefault("APP_ENV", "unknown") %>
Java        : <%= System.getProperty("java.vendor") %> <%= System.getProperty("java.version") %>
Timestamp   : <%= new java.util.Date() %>
