/*******************************************************************************
 * Copyright (c) 2020, 2021 Red Hat, IBM Corporation and others.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *******************************************************************************/
package org.restcrud;

import java.util.Date;
import java.text.SimpleDateFormat;

import javax.enterprise.context.ApplicationScoped;
import javax.enterprise.event.Observes;
import javax.inject.Inject;
import javax.json.Json;
import javax.persistence.EntityManager;
import javax.transaction.Transactional;
import javax.ws.rs.Consumes;
import javax.ws.rs.DELETE;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.PUT;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.WebApplicationException;
import javax.ws.rs.core.Response;
import javax.ws.rs.ext.ExceptionMapper;
import javax.ws.rs.ext.Provider;

import org.eclipse.microprofile.metrics.annotation.Timed;
import org.jboss.resteasy.annotations.jaxrs.PathParam;

import io.quarkus.runtime.StartupEvent;

@Path("galaxies")
@ApplicationScoped
@Produces("application/json")
@Consumes("application/json")
public class Galaxies {

    @Inject
    EntityManager entityManager;

	@GET
    @Path("hello")
	public String getStatus() {
		return "hello";
	}

    @GET
    @Timed(
        name="getop.timer",
        displayName="Time it takes to retrieve galaxy(ies)",
        description="Display galaxy(ies)",
        reusable=true)
    public Galaxy[] get() {
        return entityManager.createNamedQuery("Galaxies.findAll", Galaxy.class)
                .getResultList().toArray(new Galaxy[0]);
    }

    @GET
    @Path("{id}")
    @Timed(
        name="getop.timer",
        displayName="Time it takes to retrieve galaxy(ies)",
        description="Display galaxy(ies)",
        reusable=true)
    public Galaxy get(@PathParam Integer id) {
        Galaxy entity = entityManager.find(Galaxy.class, id);
        if (entity == null) {
            throw new WebApplicationException("Galaxy with id of " + id + " does not exist.", 404);
        }
        return entity;
    }

    @POST
    @Consumes("application/json")
    @Produces("application/json")
    @Transactional
    @Timed(
        name="doop.timer",
        displayName="Update galaxy(ies)",
        description="Update galaxy(ies)",
        reusable=true)
    public Response create(Galaxy galaxy) {
        if (galaxy.getId() != null) {
            throw new WebApplicationException("Id was invalidly set on request.", 422);
        }

        entityManager.persist(galaxy);
        return Response.ok(galaxy).status(201).build();
    }

    @PUT
    @Path("{id}")
    @Transactional
    @Timed(
        name="doop.timer",
        displayName="Update galaxy(ies)",
        description="Update galaxy(ies)",
        reusable=true)
    public Galaxy update(@PathParam Integer id, Galaxy galaxy) {
        if (galaxy.getName() == null) {
            throw new WebApplicationException("Fruit Name was not set on request.", 422);
        }

        Galaxy entity = entityManager.find(Galaxy.class, id);

        if (entity == null) {
            throw new WebApplicationException("Fruit with id of " + id + " does not exist.", 404);
        }

        entity.setName(galaxy.getName());

        return entity;
    }

    @DELETE
    @Path("{id}")
    @Transactional
    @Timed(
        name="doop.timer",
        displayName="Update galaxy(ies)",
        description="Update galaxy(ies)",
        reusable=true)
    public Response delete(@PathParam Integer id) {
        Galaxy entity = entityManager.getReference(Galaxy.class, id);
        if (entity == null) {
            throw new WebApplicationException("Galaxy with id of " + id + " does not exist.", 404);
        }
        entityManager.remove(entity);
        return Response.status(204).build();
    }

    void onStart(@Observes StartupEvent startup) {
        System.out.println(new SimpleDateFormat("HH:mm:ss.SSS").format(new Date()));
    }

    @Provider
    public static class ErrorMapper implements ExceptionMapper<Exception> {

        @Override
        public Response toResponse(Exception exception) {
            int code = 500;
            if (exception instanceof WebApplicationException) {
                code = ((WebApplicationException) exception).getResponse().getStatus();
            }
            return Response.status(code)
                    .entity(Json.createObjectBuilder().add("error", exception.getMessage()).add("code", code).build())
                    .build();
        }

    }
}
