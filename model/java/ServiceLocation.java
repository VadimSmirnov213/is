package ru.itmo.autoservice.model;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "service_locations", schema = "autoservice")
public class ServiceLocation {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(nullable = false)
    private String address;

    private String phone;

    @Column(name = "work_schedule")
    private String workSchedule;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;
}
