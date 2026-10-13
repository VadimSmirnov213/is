package ru.itmo.autoservice.model;

import jakarta.persistence.*;

@Entity
@Table(name = "request_statuses", schema = "autoservice")
public class RequestStatus {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Short id;

    @Column(nullable = false, unique = true, length = 40)
    private String code;

    @Column(name = "name_ru", nullable = false, length = 80)
    private String nameRu;

    @Column(name = "is_terminal", nullable = false)
    private boolean terminal;
}
