---
layout: post
title:  "Java REST method with JSON content"
description: "REST method in Java to consume and produce JSON data"
date:   2019-04-04 22:48:35
categories: development
tags: [java, jersey]
comments: true
---

* TOC
{:toc}

As any other language supporting web frameworks, Java (and specifically the Java API for RESTful services, <code>javax.ws</code>) provides tools to define REST APIs in a very convenient way. Among these APIs, it is common to operate with data in JSON.

This post provides a sample (**non-comprehensive, non-working example** that you may need to adapt) of a REST endpoint that consumes some JSON structure and produces an output in the same format.

<!--more-->

### Server side

In this first step the specific endpoint is defined and implemented at the side of the server.

**Users.java**

{% include codeblock-header.html %}
```java
package com.github.carolinafernandez.api;

import com.github.carolinafernandez.exception.ApiException;
import com.github.carolinafernandez.helpers.Roles;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import javax.ws.rs.Consumes;
import javax.ws.rs.Path;
import javax.ws.rs.POST;
import javax.ws.rs.Produces;

public interface Users {

    @POST
    @Path("/users/validate")
    @Consumes({MediaType.APPLICATION_JSON})
    @Produces({MediaType.APPLICATION_JSON})
    Response validateUserData(
            String userId
    )
            throws ApiException;
}
```

**UsersImpl.java**

{% include codeblock-header.html %}
```java
package com.github.carolinafernandez.api.impl;

import com.github.carolinafernandez.api.Users;
import com.github.carolinafernandez.exception.ApiException;
import com.github.carolinafernandez.model.User;
import javax.ws.rs.core.Response;

public class UsersImpl implements Users {

    @Override
    public Response validateUser(String userId) throws ApiException {

        String returnedReply = "{\"user_id\": \"%s\", \"result\": \"%s\"}";
        boolean isUserDataValid = false;
        try {
            User user = /* Obtain user from database based on its ID */;
            if (user != null && user.getId() != null && userId.equals(user.getId())) {
              isUserDataValid = true;
              returnedReply = String.format(returnedReply, userId, String.valueOf(isUserDataValid));
              return Response.status(validateUserDataHTTPCode).entity(outputDetails).build();
            }
        } catch (Exception exc) {
            throw new ApiException(exc, Response.Status.INTERNAL_SERVER_ERROR);
        }
        Response.Status returnedHttpCode = isUserDataValid ? Response.Status.OK : Response.Status.CONFLICT;
        String outputDetails = String.format(returnedReply, String.valueOf(isUserDataValid),
                validateUserDataDetails);
        logger.info("Result from validation: " + outputDetails);
        return Response.status(returnedHttpCode).entity(outputDetails).build();
    }
}
```

Now, the following call in cURL would suffice to test the proper behaviour of the server side.

{% include codeblock-header.html %}
```bash
curl -X  POST -v --include -H "X-token:424862d3-5ea4-429b-9a39-d783e9607543 " -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"User\":{\"id\":\"usertest\",\"password\":\"usertest\",\"organisation\":\"YourCompany\",\"name\":\"Jane Doe\",\"email\":\"jane.doe@your.org\",\"roles\":[\"ADMIN\"]}}" http://127.0.0.1:8181/users/validate
```

### Client side

The client side is responsible for interfacing with the API to retrieve the data (<code>RestClient.java</code>). This data can be parsed in the same client (<code>UserController.java</code> and related validation in <code>UserValidator.java</code>) or in the rest of the software that uses the client to communicate with the core side.

**RestClient.java**

{% include codeblock-header.html %}
```java
package com.github.carolinafernandez.client;

import java.net.URLEncoder;
import java.util.HashMap;
import java.util.Map;
import javax.ws.rs.client.Entity;
import javax.ws.rs.client.Invocation.Builder;
import javax.ws.rs.core.Configurable;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import org.apache.log4j.Logger;
import org.glassfish.jersey.media.multipart.MultiPartFeature;

public class RestClient {

    private static final Logger LOG = Logger.getLogger(RestClient.class);

    private Builder prepareRequest(String absoluteUrl, MediaType consumedMediaType, String token) {
  		if (consumedMediaType.equals(MediaType.MULTIPART_FORM_DATA_TYPE)) {
        ((Configurable) client).register(classType);
  		}
  		Builder request = client.target(absoluteUrl).request();
  		return request.header("X-token", token);
  	}

    private Response fetchPostResponse(String endpoint, Object consumedObject, MediaType consumedMediaType, String token) {
  		Builder builder = prepareRequest(endpoint, consumedMediaType, token);
  		Response response = null;
  		Entity entity = null;
  		try {
  			if (consumedObject != null && consumedMediaType != null) {
  				entity = Entity.entity(consumedObject, consumedMediaType);
  			}
  			LOG.info(String.format("[rest-client] Sending action=%s on endpoint=%s (entity=%s with content=%s)",
  					"POST", formatEndpoint(endpoint), entity != null ? entity.toString() : "null",
  					consumedObject != null ? consumedObject.toString() : "null"));
  			response = builder.post(entity);
  		} catch (Exception e) {
  			throw new ApiException(e);
  		}
  		return response;
  	}

    protected Map<Boolean, String> validateUserData(User user, String token) {
        Response response = null;
        // Structure to hold (result_of_operation, details_of_operation)
        Map<Boolean, String> validationResult = new HashMap<>();
        String endpointURL = String.format("%s/validate", RM_RES_ENDPOINT);
        UserCreateDTO userDTO = defineUserCreateDTO(user, false);
        try {
            response = fetchPostResponse(endpointURL, userDTO, MediaType.APPLICATION_JSON_TYPE, token);
            if (response.getStatus() == Response.Status.OK.getStatusCode() ||
                    response.getStatus() == Response.Status.CONFLICT.getStatusCode()) {
                // Even though the Content-Type is "application/json", returned value is a String
                JSONObject jsonContents = new JSONObject(response.readEntity(String.class));
                validationResult.put(jsonContents.getBoolean("result"), jsonContents.getString("detail"));
            }
        } catch (Exception e) {
            validationResult.put(false, "Could not validate user data. Details: " + e.toString());
            LOG.error("An error occurred when trying to validate the user data.", e);
        }
        return validationResult;
    }
}
```

**UserValidator.java**

{% include codeblock-header.html %}
```java
package com.github.carolinafernandez.validator;

import com.github.carolinafernandez.client.RestClient;
import com.github.carolinafernandez.model.User;
import java.util.HashMap;
import java.util.Map;
import org.apache.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.validation.Errors;
import org.springframework.validation.Validator;


@Component
public class UserValidator implements Validator {
  	@Autowired
  	private RestClient restClient;

  	@Override
  	public boolean supports(Class<?> clazz) {
  		return clazz.isAssignableFrom(User.class);
  	}

  	private static final Logger LOG = Logger.getLogger(UserValidator.class);

  	private Map<Boolean, String> validateUserData(User user) {
  		Map<Boolean, String> validationResult = new HashMap<>();
  		try {
  			validationResult = restClient.validateUserData(user);
  		} catch (Exception e) {
  			LOG.debug(e);
  		}
  		return validationResult;
  	}

  	@Override
  	public void validate(Object target, Errors errors) {
    		User user = (User) target;
    		Map.Entry<Boolean, String> validateResult = validateUserData(user).entrySet().iterator().next();
    		if (!validateResult.getKey()) {
    			  errors.rejectValue("field_dom_id", "field_error_dom_id", "Specific error message here");
    		}
  	}
}
```

**UserController.java**

{% include codeblock-header.html %}
```java
package com.github.carolinafernandez.controller;

import com.github.carolinafernandez.exception.RestClientException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import com.github.carolinafernandez.model.User;
import org.apache.log4j.Logger;

@Controller
public class UserController {

    private static final Logger LOG = Logger.getLogger(UserController.class);

    @Autowired
    RestEndpoints restClient;

    @Autowired
    private UserValidator userValidator;

    @InitBinder("userModel")
    protected void initBinder(WebDataBinder binder) {
        binder.setValidator(userModelValidator);
    }

    @RequestMapping({ "/user/update/submit" })
    public String updateUser(Model model, User user) throws RestClientException {
        Map<Boolean, String> validationResult = new HashMap<>();
        try {
          validationResult = restClient.validateUserData(user);
        } catch (Exception e) {
          LOG.debug(e);
        }
        model.addAttribute("validation", validationResult);
        // Return to the user page after updating its profile
        return "/user/show";
    }
}
```
