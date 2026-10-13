package ru.itmo.autoservice.model;

import jakarta.persistence.*;

@Entity
@Table(name = "roles", schema = "autoservice")
public class Role {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Short id;

    @Column(nullable = false, unique = true, length = 32)
    private String code;

    @Column(name = "name_ru", nullable = false, length = 64)
    private String nameRu;

    public Short getId() { return id; }
    public String getCode() { return code; }
    public String getNameRu() { return nameRu; }
}
