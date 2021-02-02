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
