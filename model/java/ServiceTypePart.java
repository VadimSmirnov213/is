package ru.itmo.autoservice.model;

import jakarta.persistence.*;
import java.io.Serializable;

@Entity
@Table(name = "service_type_parts", schema = "autoservice")
@IdClass(ServiceTypePart.Pk.class)
public class ServiceTypePart {
    @Id
    @Column(name = "service_type_id")
    private Long serviceTypeId;

    @Id
    @Column(name = "part_id")
    private Long partId;

    @ManyToOne(optional = false)
    @JoinColumn(name = "service_type_id", insertable = false, updatable = false)
    private ServiceType serviceType;

    @ManyToOne(optional = false)
    @JoinColumn(name = "part_id", insertable = false, updatable = false)
    private Part part;

    @Column(name = "is_required", nullable = false)
    private boolean required;

    public static class Pk implements Serializable {
        public Long serviceTypeId;
        public Long partId;
    }
}
