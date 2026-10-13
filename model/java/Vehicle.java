package ru.itmo.autoservice.model;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "vehicles", schema = "autoservice")
public class Vehicle {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "owner_id", nullable = false)
    private User owner;

    @Column(nullable = false, length = 80)
    private String make;

    @Column(nullable = false, length = 80)
    private String model;

    @Column(nullable = false)
    private Integer year;

    @Column(name = "plate_number", nullable = false, unique = true, length = 20)
    private String plateNumber;

    @Column(unique = true, length = 32)
    private String vin;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;
}
