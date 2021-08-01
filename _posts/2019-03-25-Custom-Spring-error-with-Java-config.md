---
layout: post
title:  "Spring custom error with Java config"
description: "Custom error in Spring web framework by using Java config"
date:   2019-03-25 23:51:07
categories: development
tags: [java, spring]
comments: true
---

* TOC
{:toc}

The Spring web framework allows Java developers to define a web-based application in a relatively easy way. Multiple features are provided to that matter: XML and Java-like configurations, handling the initialisation of a web application more easily, managing the data via controllers and so on.

This post documents how to define custom errors, for instance those with custom 404/not-found error pages. The information below is taken from [my own experience and answer in StackOverflow](https://stackoverflow.com/questions/55028538/404-error-in-spring-java-config-no-web-xml/55053827#55053827).

<!--more-->

### Problem

Typically, the definition of a custom error page in Spring is documented as a change in the web.xml file. However, when using Java config, the configuration is likely to be way more complex. This post defines how to define a custom error page in a Spring web app that does not use XML-based configuration nor any other specific library for templates such as Thymeleaf.

### Solution

The following files are defined or modified:

#### Java classes

First, the <code>SimpleMappingExceptionResolver</code> is extended to handle any exception and process any output in the "ModelAndView" object. This class can be registered later in the configuration of the web application so that it acts as the default resolver.

**CustomSimpleMappingExceptionResolver.java**

{% include codeblock-header.html %}
```java
package ...;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import javax.ws.rs.InternalServerErrorException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.springframework.http.HttpStatus;
import org.springframework.web.servlet.handler.SimpleMappingExceptionResolver;
import org.springframework.web.servlet.ModelAndView;
import org.springframework.web.servlet.NoHandlerFoundException;

public class CustomSimpleMappingExceptionResolver extends SimpleMappingExceptionResolver {

    public CustomSimpleMappingExceptionResolver() {
        // Turn logging on by default
        setWarnLogCategory(getClass().getName());
    }

    @Override
    public String buildLogMessage(Exception e, HttpServletRequest req) {
        return "MVC exception: " + e.getLocalizedMessage();
    }

    @Override
    protected ModelAndView doResolveException(HttpServletRequest request, HttpServletResponse response,
                                              Object handler, Exception ex) {

        // Log exception
        ex.printStackTrace();
        String exceptionCause = ex.toString();
        String exceptionType = ex.getClass().getCanonicalName();

        // Get the ModelAndView to use
        ModelAndView mav = super.doResolveException(request, response, handler, ex);

        // Make more information available to the view - note that SimpleMappingExceptionResolver adds the exception already
        mav.addObject("url", request.getRequestURL());
        mav.addObject("timestamp", new Date());

        ArrayList<String> exceptions404 = new ArrayList<String>(
                Arrays.asList(
                        NoHandlerFoundException.class.getName()
                        )
        );
        ArrayList<String> exceptions500 = new ArrayList<String>(
                Arrays.asList(
                        InternalServerErrorException.class.getName(),
                        NullPointerException.class.getName()
                        )
        );

        String userExceptionDetail = ex.toString();
        String errorHuman = "";
        String errorTech = "";

        if (exceptions404.contains(exceptionType)) {
            errorHuman = "We cannot find the page you are looking for";
            errorTech = "Page not found";
            userExceptionDetail = String.format("The page %s cannot be found", request.getRequestURL());
            mav.setViewName("/error/404");
            mav.addObject("status", HttpStatus.NOT_FOUND.value());
        } else if (exceptions500.contains(exceptionType)) {
            errorHuman = "We cannot currently serve the page you request";
            errorTech = "Internal error";
            userExceptionDetail = "The current page refuses to load due to an internal error";
            mav.setViewName("/error/500");
            mav.addObject("status", HttpStatus.INTERNAL_SERVER_ERROR.value());
        } else {
            errorHuman = "We cannot serve the current page";
            errorTech = "General error";
            userExceptionDetail = "A generic error prevents from serving the page";
            mav.setViewName("/error/generic");
            mav.addObject("status", response.getStatus());
        }

        Exception userException = new Exception(userExceptionDetail);
        mav.addObject("error_human", errorHuman);
        mav.addObject("error_tech", errorTech);
        mav.addObject("exception", userException);
        return mav;
    }
}
```

Now, the custom exception resolved is registered as the default exception handler. More information can be defined, such as setting a mapping between any given exception -- this can be done either importing it and providing the class name or by providing the full path via a string. Other operations are defining specific and default HTTP codes, default error views, setting the precedence of the processing and the like.

**WebAppConfig.java**

{% include codeblock-header.html %}
```java
package ...;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;
import org.springframework.context.annotation.Scope;
import org.springframework.context.annotation.ScopedProxyMode;
import org.springframework.core.env.Environment;
import org.springframework.core.Ordered;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import org.springframework.web.servlet.config.annotation.EnableWebMvc;
import org.springframework.web.servlet.config.annotation.ViewControllerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurerAdapter;
import org.springframework.web.servlet.HandlerExceptionResolver;
import org.springframework.web.servlet.NoHandlerFoundException;
import org.springframework.web.servlet.view.InternalResourceViewResolver;

import java.lang.ClassNotFoundException;
import java.lang.NullPointerException;
import javax.annotation.Resource;
import javax.ws.rs.InternalServerErrorException;
import java.util.Properties;

@Configuration
@ComponentScan("...")
@EnableWebMvc
@EnableTransactionManagement
@PropertySource("classpath:application.properties")
public class WebAppConfig extends WebMvcConfigurerAdapter {

    @Resource
    private Environment env;

    // ...

    @Bean
    HandlerExceptionResolver customExceptionResolver () {
        CustomSimpleMappingExceptionResolver resolver = new CustomSimpleMappingExceptionResolver();
        Properties mappings = new Properties();
        // Mapping Spring internal error NoHandlerFoundException to a view name
        mappings.setProperty(NoHandlerFoundException.class.getName(), "/error/404");
        mappings.setProperty(InternalServerErrorException.class.getName(), "/error/500");
        mappings.setProperty(NullPointerException.class.getName(), "/error/500");
        mappings.setProperty(ClassNotFoundException.class.getName(), "/error/500");
        mappings.setProperty(Exception.class.getName(), "/error/generic");
        resolver.setExceptionMappings(mappings);
        // Set specific HTTP codes
        resolver.addStatusCode("404", HttpStatus.NOT_FOUND.value());
        resolver.addStatusCode("500", HttpStatus.INTERNAL_SERVER_ERROR.value());
        resolver.setDefaultErrorView("/error/generic");
        resolver.setDefaultStatusCode(200);
        // This resolver will be processed before the default ones
        resolver.setOrder(Ordered.HIGHEST_PRECEDENCE);
        resolver.setExceptionAttribute("exception");
        return resolver;
    }

    // ...

    @Bean
    public InternalResourceViewResolver setupViewResolver() {
        InternalResourceViewResolver resolver = new InternalResourceViewResolver();
        resolver.setPrefix("/WEB-INF/views");
        resolver.setSuffix(".jsp");
        resolver.setExposeContextBeansAsAttributes(true);
        return resolver;
    }

    @Override
    public void addViewControllers(ViewControllerRegistry registry) {
        super.addViewControllers(registry);
    }
}
```

Now that the custom resolver is registered in the configuration of the web application, the object for the latter (the configuration via Java config) must be registered as well in the initialising class for the web application.

**Initializer.java**

{% include codeblock-header.html %}
```java
package ...;

import org.springframework.web.WebApplicationInitializer;
import org.springframework.web.context.ContextLoaderListener;
import org.springframework.web.context.support.AnnotationConfigWebApplicationContext;
import org.springframework.web.servlet.DispatcherServlet;

import javax.servlet.ServletContext;
import javax.servlet.ServletException;
import javax.servlet.ServletRegistration;

public class Initializer implements WebApplicationInitializer {

    public void onStartup(ServletContext servletContext) throws ServletException {
        AnnotationConfigWebApplicationContext ctx = new AnnotationConfigWebApplicationContext();
        ctx.register(WebAppConfig.class);
        servletContext.addListener(new ContextLoaderListener(ctx));
        ctx.setServletContext(servletContext);
        DispatcherServlet dispatcherServlet = new DispatcherServlet(ctx);
        // Note: the line below may not be needed
        dispatcherServlet.setThrowExceptionIfNoHandlerFound(true);

        // Add the dispatcher servlet mapping manually and make it initialize automatically
        ServletRegistration.Dynamic servlet = servletContext.addServlet("dispatcher", dispatcherServlet);
        servlet.addMapping("/");
        servlet.addMapping("*.png");
        servlet.addMapping("*.jpg");
        servlet.addMapping("*.css");
        servlet.addMapping("*.js");
        servlet.addMapping("*.txt");
        servlet.setLoadOnStartup(1);

        // ...

    }
}
```

#### Tags and views

Besides the Java classes, there is content to be provided either as tags or views. In this example, we provide a tag file that can be parameterised in different views (one per error code), The structure of such files is as follows:

```
src/main/webapp/WEB-INF/
├── tags
│   └── error.tag
└── views
    ├── error
    │   ├── 404.jsp
    │   ├── 500.jsp
    └────── generic.jsp
```

**src/main/webapp/WEB-INF/tags/error.tag**: a templated error tag to be used in the error views

{% include codeblock-header.html %}
```jstl
<%@taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>

<!DOCTYPE html>
<head>
    <title>Error page</title>
</head>
<body>
<div class="container">
    <h3><c:out value="${error_human}" /></h3>

    <p><br/><br/></p>

    <div class="panel panel-primary">
        <div class="panel-heading">
            <c:out value="${error_tech}" />
        </div>
        <div class="panel-body">
            <p><c:out value="${exception_message}" /></p>
        </div>
    </div>
</div>
</body>
</html>
```

**src/main/webapp/WEB-INF/views/error/404.jsp**: a 404 error-related template

{% include codeblock-header.html %}
```jstl
<%@ page language="java" contentType="text/html; charset=utf-8"
         pageEncoding="utf-8" isErrorPage="true" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib tagdir="/WEB-INF/tags/" prefix="g" %>

<c:set var = "error_human" scope = "session" value = "We cannot find the page you are looking for"/>
<c:set var = "error_tech" scope = "session" value = "Page not found"/>
<c:set var = "exception_message" scope = "session" value = "The current page cannot be found"/>
<g:error />
```

**src/main/webapp/WEB-INF/views/error/500.jsp**: a 500 error-related template

{% include codeblock-header.html %}
```jstl
<%@ page language="java" contentType="text/html; charset=utf-8"
         pageEncoding="utf-8" isErrorPage="true" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib tagdir="/WEB-INF/tags/" prefix="g" %>

<c:set var = "error_human" scope = "session" value = "We cannot currently serve the page you request"/>
<c:set var = "error_tech" scope = "session" value = "Internal error"/>
<c:set var = "exception_message" scope = "session" value = "The current page refuses to load due to an internal error"/>
<g:error />
```

**src/main/webapp/WEB-INF/views/error/generic.jsp**: a generic error template (for anything that does not fit the cases above and *can be captured by the Spring framework*)

{% include codeblock-header.html %}
```jstl
<%@ page language="java" contentType="text/html; charset=utf-8"
         pageEncoding="utf-8" isErrorPage="true" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib tagdir="/WEB-INF/tags/" prefix="g" %>

<c:set var = "error_human" scope = "session" value = "We cannot serve the current page"/>
<c:set var = "error_tech" scope = "session" value = "General error"/>
<c:set var = "exception_message" scope = "session" value = "A generic error prevents from serving the page"/>
<g:error />
```

With this, any error defined in <code>CustomSimpleMappingExceptionResolver.java</code> (that is, any exception or HTTP code or any other servlet request or response) and which can be caught (e.g., errors in JSTL templates are likely to **not** be intercepted) will be handled and a specific error page will be displayed instead of the custom web server error page.

Finally, a possibly good measure to combine with this is to turn off the debugging in the web server (e.g., [example for Tomcat](https://stackoverflow.com/questions/794329/disable-all-default-http-error-response-content-in-tomcat)), so even under unexpected errors there will be no traces of information provided to the end user.
