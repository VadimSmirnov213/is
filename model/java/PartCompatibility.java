package ru.itmo.autoservice.model;

import jakarta.persistence.*;

@Entity
@Table(name = "part_compatibilities", schema = "autoservice")
public class PartCompatibility {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "part_id", nullable = false)
    private Part part;

    @Column(nullable = false, length = 80)
    private String make;

    @Column(nullable = false, length = 80)
    private String model;

    @Column(name = "year_from")
    private Integer yearFrom;

    @Column(name = "year_to")
    private Integer yearTo;
}
