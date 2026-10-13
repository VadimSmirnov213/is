package ru.itmo.autoservice.model;

import jakarta.persistence.*;
import java.io.Serializable;
import java.time.OffsetDateTime;

@Entity
@Table(name = "mechanic_locations", schema = "autoservice")
@IdClass(MechanicLocation.Pk.class)
public class MechanicLocation {
    @Id
    @Column(name = "mechanic_id")
    private Long mechanicId;

    @Id
    @Column(name = "location_id")
    private Long locationId;

    @ManyToOne(optional = false)
    @JoinColumn(name = "mechanic_id", insertable = false, updatable = false)
    private User mechanic;

    @ManyToOne(optional = false)
    @JoinColumn(name = "location_id", insertable = false, updatable = false)
    private ServiceLocation location;

    @Column(name = "assigned_at", nullable = false)
    private OffsetDateTime assignedAt;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;

    public static class Pk implements Serializable {
        public Long mechanicId;
        public Long locationId;
    }
}
