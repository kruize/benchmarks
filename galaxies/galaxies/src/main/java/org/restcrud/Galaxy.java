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

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.NamedQuery;
import javax.persistence.SequenceGenerator;
import javax.persistence.Table;

@Entity
@Table(name = "galaxies")
@NamedQuery(name = "Galaxies.findAll",
    query = "SELECT glxy FROM Galaxy glxy ORDER BY glxy.name")
public class Galaxy {

    @Id
    @SequenceGenerator(
            name = "galaxySequence",
            sequenceName = "galaxies_id_seq",
            allocationSize = 1,
            initialValue = 4)
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "galaxySequence")
    private Integer id;

    @Column(length = 50, unique = true)
    private String name;

    public Galaxy() {
    }

    public Galaxy(String name) {
        this.name = name;
    }

    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }
}
